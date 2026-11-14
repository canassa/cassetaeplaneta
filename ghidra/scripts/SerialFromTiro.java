import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.framework.model.DomainFile;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

// Transfer a sibling build's analysis (TIRO.EXE, read only) onto the current program by address.
// SERIAL.EXE and TIRO.EXE are the same engine built with the same options; their engine segments
// align byte for byte except for DGROUP immediates, so a TIRO function maps to one SERIAL address.
//
// Args:
//   types <src program> <src category> <dst category> [T:Old=New ...]
//       Copy every data type of the source category (and what it depends on) into the current
//       program, then move the copies to the destination category; T:Old=New renames a type.
//   fns <src program> <map tsv> <src category> <dst category> [old=new ...] [T:Old=New ...]
//       One row per function: <dst entry> \t <src entry> \t <src name> \t <dst ranges|-> \t <q>.
//       Ranges are `lo-hi,...` offsets in the dst entry's segment ("-" = keep the body Ghidra made).
//       For each row: make the function at dst (removing a function that wrongly contains or
//       starts next to the entry), set the body to the mapped ranges, then copy the name (old=new
//       substrings applied, e.g. tiro_=serial_), the calling convention, return and parameter
//       types (source category types resolved by name in the destination category, T:Old=New as in types), no-return,
//       tags and the plate. The plate gets a first line
//       "Name from TIRO <name> at <addr> (byte-aligned, q=<q>)". Thunks (`*_thunk*`) are skipped:
//       NearAdjustorThunks names them after their targets.
public class SerialFromTiro extends GhidraScript {
	Program sp;
	CategoryPath srcCat, dstCat;
	List<String[]> renames = new ArrayList<>(), typeRenames = new ArrayList<>();

	String rename(String n) {
		for (String[] r : renames) n = n.replace(r[0], r[1]);
		return n;
	}

	String renameType(String n) {
		for (String[] r : typeRenames) if (n.equals(r[0])) return r[1];
		return n;
	}

	void addRename(String arg) {
		if (arg.startsWith("T:")) typeRenames.add(arg.substring(2).split("=", 2));
		else renames.add(arg.split("=", 2));
	}

	DataType map(DataType dt) {
		DataTypeManager td = currentProgram.getDataTypeManager();
		if (dt == null) return null;
		if (dt instanceof Pointer) {
			Pointer p = (Pointer) dt;
			DataType b = map(p.getDataType());
			return td.getPointer(b, p.getLength());
		}
		if (dt instanceof Array) {
			Array a = (Array) dt;
			return new ArrayDataType(map(a.getDataType()), a.getNumElements(), a.getElementLength(), td);
		}
		CategoryPath c = dt.getCategoryPath();
		if (c.isAncestorOrSelf(srcCat)) {
			String rel = c.getPath().substring(srcCat.getPath().length());
			CategoryPath dc = new CategoryPath(dstCat.getPath() + rel);
			DataType d = td.getDataType(dc, renameType(dt.getName()));
			if (d != null) return d;
			println("  type missing in dst: " + dc + "/" + dt.getName());
		}
		DataType root = td.getDataType(dt.getCategoryPath(), dt.getName());
		if (root != null) return root;
		return td.resolve(dt, DataTypeConflictHandler.KEEP_HANDLER);
	}

	void types(String[] a) throws Exception {
		DataTypeManager sd = sp.getDataTypeManager(), td = currentProgram.getDataTypeManager();
		Category sc = sd.getCategory(srcCat);
		List<DataType> all = new ArrayList<>();
		collect(sc, all);
		int n = 0;
		for (DataType dt : all) {
			td.addDataType(dt, DataTypeConflictHandler.KEEP_HANDLER);
			n++;
		}
		Category c = td.getCategory(srcCat);
		if (c != null && !srcCat.equals(dstCat)) c.setName(dstCat.getName());
		for (String[] r : typeRenames) {
			DataType d = td.getDataType(dstCat, r[0]);
			if (d != null) d.setName(r[1]);
		}
		println("copied " + n + " types into " + dstCat);
	}

	void collect(Category c, List<DataType> out) {
		out.addAll(Arrays.asList(c.getDataTypes()));
		for (Category s : c.getCategories()) collect(s, out);
	}

	Function mk(Address x) throws Exception {
		Function f = getFunctionAt(x);
		if (f != null) return f;
		Function in = getFunctionContaining(x);
		if (in != null) { println("  remove " + in.getEntryPoint() + " " + in.getName() + " (contains " + x + ")"); removeFunction(in); }
		Function next = getFunctionAt(x.add(1));
		if (next != null) { println("  remove " + next.getEntryPoint() + " (entry one byte late)"); removeFunction(next); }
		if (getInstructionAt(x) == null) { clearListing(x); disassemble(x); }
		return createFunction(x, null);
	}

	void fns(String[] a) throws Exception {
		int n = 0, bodies = 0, fail = 0;
		try (BufferedReader r = new BufferedReader(new FileReader(a[2]))) {
			for (String line; (line = r.readLine()) != null;) {
				String[] p = line.split("\t", -1);
				Address dx = toAddr(p[0]);
				Function src = sp.getFunctionManager().getFunctionAt(sp.getAddressFactory().getAddress(p[1]));
				if (src == null || src.getName().contains("_thunk")) continue;
				Function f = mk(dx);
				if (f == null) { println("FAILED create " + dx); fail++; continue; }
				if (!p[3].equals("-")) {
					AddressSet body = new AddressSet();
					for (String rg : p[3].split(",")) {
						String[] lh = rg.split("-");
						Address lo = toAddr(dx.toString().substring(0, 5) + lh[0]), hi = toAddr(dx.toString().substring(0, 5) + lh[1]);
						body.add(lo, hi);
						if (getInstructionAt(lo) == null) disassemble(lo);
					}
					if (!body.equals(f.getBody())) {
						try { f.setBody(body); bodies++; }
						catch (Exception e) { println("  body " + dx + ": " + e.getMessage()); }
					}
				}
				copy(src, f, p[4]);
				n++;
			}
		}
		println("functions " + n + ", bodies set " + bodies + ", failed " + fail);
	}

	void copy(Function s, Function f, String q) throws Exception {
		f.setName(rename(s.getName()), SourceType.USER_DEFINED);
		List<ParameterImpl> ps = new ArrayList<>();
		for (Parameter p : s.getParameters()) ps.add(new ParameterImpl(p.getName(), map(p.getDataType()), currentProgram));
		ReturnParameterImpl ret = new ReturnParameterImpl(map(s.getReturnType()), currentProgram);
		String cc = s.getCallingConventionName();
		if (currentProgram.getCompilerSpec().getCallingConvention(cc) == null && !cc.equals("unknown") && !cc.equals("default"))
			println("  cc missing: " + cc + " for " + f.getEntryPoint());
		try {
			f.updateFunction(cc, ret, ps, Function.FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true,
				s.getSignatureSource() == SourceType.DEFAULT ? SourceType.ANALYSIS : SourceType.USER_DEFINED);
		}
		catch (Exception e) { println("  proto " + f.getEntryPoint() + ": " + e.getMessage()); }
		f.setVarArgs(s.hasVarArgs());
		f.setNoReturn(s.hasNoReturn());
		if (s.getCallFixup() != null) f.setCallFixup(s.getCallFixup());
		for (FunctionTag t : s.getTags()) f.addTag(t.getName());
		String pl = s.getComment();
		String head = "Name from TIRO " + s.getName() + " at " + s.getEntryPoint() + " (byte-aligned, q=" + q + ")";
		f.setComment(pl == null || pl.isEmpty() ? head : head + "\n" + rename(pl));
	}

	public void run() throws Exception {
		String[] a = getScriptArgs();
		DomainFile df = state.getProject().getProjectData().getFile(a[1]);
		sp = (Program) df.getReadOnlyDomainObject(this, -1, monitor);
		try {
			if (a[0].equals("types")) {
				srcCat = new CategoryPath(a[2]); dstCat = new CategoryPath(a[3]);
				for (int i = 4; i < a.length; i++) addRename(a[i]);
				types(a);
			}
			else {
				srcCat = new CategoryPath(a[3]); dstCat = new CategoryPath(a[4]);
				for (int i = 5; i < a.length; i++) addRename(a[i]);
				fns(a);
			}
		}
		finally { sp.release(this); }
	}
}
