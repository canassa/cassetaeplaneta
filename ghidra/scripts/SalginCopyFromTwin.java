import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;

// Copy types, and function names/prototypes/plates/tags, from a twin program (read only) built from
// the same engine sources (e.g. a minigame from TIRO.EXE). The twin is never modified.
// Args: <twin program path> <twin category> <own category> <mode> [file]
//   types        resolve every type of the twin category (and what it depends on) into the current
//                program, under the own category (e.g. /tiro -> /salgin). Existing types are kept.
//   fns <tsv>    each line "own seg:off TAB twin seg:off TAB method" ('#' = comment): the own function
//                gets the twin's name (only while it still has a default FUN_ name, or with method
//                prefixed '!'), its calling convention, return and parameter types (twin category
//                types mapped by name to the own category), no-return flag, call-fixup and tags; and a
//                plate "Name from <TWIN> <name> at <addr> (<method>)." followed by the twin's plate
//                (only when the function has no plate, or always with '!'). Functions whose twin is an adjustor thunk
//                (name *_thunk*) only get the name; the signature is left alone.
public class SalginCopyFromTwin extends GhidraScript {
	DataTypeManager td;
	CategoryPath srcCat, dstCat;

	DataType map(DataType dt) {
		if (dt == null) return null;
		if (dt instanceof Pointer) {
			Pointer p = (Pointer) dt;
			DataType b = p.getDataType() == null ? null : map(p.getDataType());
			return new PointerDataType(b, p.getLength(), td);
		}
		if (dt instanceof Array) {
			Array a = (Array) dt;
			return new ArrayDataType(map(a.getDataType()), a.getNumElements(), a.getElementLength(), td);
		}
		CategoryPath cp = dt.getCategoryPath();
		if (cp.equals(srcCat) || cp.toString().startsWith(srcCat.toString() + "/")) {
			String rel = cp.toString().substring(srcCat.toString().length());
			DataType own = td.getDataType(new CategoryPath(dstCat.toString() + rel), dt.getName());
			if (own != null) return own;
			println("  type not in own category, resolved as is: " + dt.getPathName());
		}
		return td.resolve(dt, DataTypeConflictHandler.KEEP_HANDLER);
	}

	public void run() throws Exception {
		String[] a = getScriptArgs();
		Program sp = (Program) state.getProject().getProjectData().getFile(a[0]).getReadOnlyDomainObject(this, -1, monitor);
		String twin = a[0].replaceAll("^/", "").replaceAll("\\.EXE$", "");
		srcCat = new CategoryPath(a[1]);
		dstCat = new CategoryPath(a[2]);
		td = currentProgram.getDataTypeManager();
		try {
			if (a[3].equals("types")) {
				Category sc = sp.getDataTypeManager().getCategory(srcCat);
				List<DataType> all = new ArrayList<>();
				collect(sc, all);
				Category tmp = td.createCategory(srcCat);
				int n = 0;
				for (DataType dt : all) {
					String rel = dt.getCategoryPath().toString().substring(srcCat.toString().length());
					if (td.getDataType(new CategoryPath(dstCat.toString() + rel), dt.getName()) != null) continue;
					td.resolve(dt, DataTypeConflictHandler.KEEP_HANDLER);
					n++;
				}
				// move everything that landed in the twin category into the own one
				Category dc = td.createCategory(dstCat);
				moveAll(td.getCategory(srcCat), dc);
				td.getRootCategory().removeEmptyCategory(srcCat.getName(), monitor);
				println("types copied " + n + " of " + all.size());
				return;
			}
			if (a[3].equals("fns")) {
				FunctionManager fm = currentProgram.getFunctionManager();
				int named = 0, sig = 0, plate = 0;
				for (String line : Files.readAllLines(Paths.get(a[4]))) {
					if (line.isBlank() || line.startsWith("#")) continue;
					String[] c = line.split("\t");
					Function f = fm.getFunctionAt(toAddr(c[0]));
					Function s = sp.getFunctionManager().getFunctionAt(sp.getAddressFactory().getAddress(c[1]));
					String method = c.length > 2 ? c[2] : "twin";
					boolean force = method.startsWith("!");
					if (force) method = method.substring(1);
					if (f == null || s == null) { println("missing " + line); continue; }
					if (force || f.getName().startsWith("FUN_") || f.getName().startsWith("thunk_FUN_")) {
						if (!f.getName().equals(s.getName())) { f.setName(s.getName(), SourceType.USER_DEFINED); named++; }
					}
					boolean thunk = s.getName().contains("_thunk");
					if (!thunk && !s.isThunk()) {
						List<ParameterImpl> ps = new ArrayList<>();
						for (Parameter p : s.getParameters())
							ps.add(new ParameterImpl(p.getName(), map(p.getDataType()), currentProgram));
						ReturnParameterImpl ret = new ReturnParameterImpl(map(s.getReturnType()), currentProgram);
						f.updateFunction(s.getCallingConventionName(), ret, ps,
							Function.FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true, s.getSignatureSource());
						f.setVarArgs(s.hasVarArgs());
						f.setNoReturn(s.hasNoReturn());
						if (s.getCallFixup() != null) f.setCallFixup(s.getCallFixup());
						sig++;
					}
					for (FunctionTag t : s.getTags()) f.addTag(t.getName());
					if (f.getComment() == null || force) {
						String sc = s.getComment();
						f.setComment("Name from " + twin + " " + s.getName() + " at " + s.getEntryPoint() + " (" + method + ")."
							+ (sc == null ? "" : "\n" + sc));
						plate++;
					}
				}
				println("named " + named + ", signatures " + sig + ", plates " + plate);
			}
		}
		finally {
			sp.release(this);
		}
	}

	void collect(Category c, List<DataType> out) {
		out.addAll(Arrays.asList(c.getDataTypes()));
		for (Category s : c.getCategories()) collect(s, out);
	}

	void moveAll(Category from, Category to) throws Exception {
		if (from == null) return;
		for (DataType dt : from.getDataTypes()) to.moveDataType(dt, DataTypeConflictHandler.KEEP_HANDLER);
		for (Category s : from.getCategories()) {
			Category t = to.getCategory(s.getName());
			if (t == null) t = to.createCategory(s.getName());
			moveAll(s, t);
		}
	}
}
