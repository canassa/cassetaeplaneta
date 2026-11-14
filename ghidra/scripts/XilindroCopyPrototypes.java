import ghidra.app.script.GhidraScript;
import ghidra.framework.model.DomainFile;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.pcode.Varnode;
import ghidra.program.model.symbol.SourceType;
import java.nio.file.*;
import java.util.*;

// Copy function prototypes from a twin build (read only) onto matched functions of the current
// program: calling convention, return type, parameter names and types, varargs, no-return and the
// `sig?` tag. Types of <srcCat> are looked up by name in <dstCat> of the current program (copy the
// category first with XilindroCopyCategory); pointers and arrays are rebuilt around the mapped base;
// other types resolve as usual. Custom variable storage is translated register for register / stack
// offset for stack offset. Functions whose source signature is still DEFAULT are skipped.
// Args: <source program> <tsv: dst addr TAB src addr> <srcCat> <dstCat> [dry]
public class XilindroCopyPrototypes extends GhidraScript {
	DataTypeManager td;
	CategoryPath src, dst;

	DataType map(DataType d) {
		if (d == null) return null;
		if (d instanceof Pointer p) {
			DataType b = p.getDataType() == null ? null : map(p.getDataType());
			return new PointerDataType(b, p.getLength(), td);
		}
		if (d instanceof Array a)
			return new ArrayDataType(map(a.getDataType()), a.getNumElements(), a.getElementLength(), td);
		if (d.getCategoryPath().equals(src) || d.getCategoryPath().isAncestorOrSelf(src)) {
			DataType m = td.getDataType(dst, d.getName());
			if (m == null) throw new RuntimeException("no " + d.getName() + " in " + dst);
			return m;
		}
		return td.resolve(d, DataTypeConflictHandler.KEEP_HANDLER);
	}

	VariableStorage storage(Variable v) throws Exception {
		Varnode[] vs = v.getVariableStorage().getVarnodes();
		Varnode[] out = new Varnode[vs.length];
		for (int i = 0; i < vs.length; i++) {
			Address sa = vs[i].getAddress();
			Address da = currentProgram.getAddressFactory().getAddressSpace(sa.getAddressSpace().getName())
				.getAddress(sa.getOffset());
			out[i] = new Varnode(da, vs[i].getSize());
		}
		return new VariableStorage(currentProgram, out);
	}

	public void run() throws Exception {
		String[] a = getScriptArgs();
		src = new CategoryPath(a[2]);
		dst = new CategoryPath(a[3]);
		boolean dry = a.length > 4 && a[4].equals("dry");
		td = currentProgram.getDataTypeManager();
		DomainFile df = state.getProject().getProjectData().getFile(a[0]);
		Program sp = (Program) df.getReadOnlyDomainObject(this, -1, monitor);
		int ok = 0, skip = 0, fail = 0;
		try {
			for (String l : Files.readAllLines(Paths.get(a[1]))) {
				if (l.isBlank() || l.startsWith("#")) continue;
				String[] c = l.split("\t");
				Function f = getFunctionAt(toAddr(c[0]));
				Function s = sp.getFunctionManager().getFunctionAt(sp.getAddressFactory().getAddress(c[1]));
				if (f == null || s == null) { println("missing " + l); fail++; continue; }
				if (s.getSignatureSource() == SourceType.DEFAULT) { skip++; continue; }
				try {
					boolean custom = s.hasCustomVariableStorage();
					List<Variable> ps = new ArrayList<>();
					for (Parameter p : s.getParameters()) {
						DataType t = map(p.getDataType());
						ps.add(custom ? new ParameterImpl(p.getName(), t, storage(p), currentProgram)
							: new ParameterImpl(p.getName(), t, currentProgram));
					}
					Parameter r = s.getReturn();
					ReturnParameterImpl ret = custom
						? new ReturnParameterImpl(map(r.getDataType()), storage(r), currentProgram)
						: new ReturnParameterImpl(map(r.getDataType()), currentProgram);
					if (!dry) {
						f.updateFunction(s.getCallingConventionName(), ret, ps,
							custom ? Function.FunctionUpdateType.CUSTOM_STORAGE
								: Function.FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS,
							true, SourceType.USER_DEFINED);
						f.setVarArgs(s.hasVarArgs());
						if (s.hasNoReturn()) f.setNoReturn(true);
						for (FunctionTag t : s.getTags()) if (t.getName().equals("sig?")) f.addTag("sig?");
					}
					ok++;
				}
				catch (Exception e) {
					println("FAIL " + c[0] + " <- " + c[1] + " " + s.getName() + ": " + e.getMessage());
					fail++;
				}
			}
		}
		finally {
			sp.release(this);
		}
		println((dry ? "[dry] " : "") + "copied " + ok + ", source untyped " + skip + ", failed " + fail);
	}
}
