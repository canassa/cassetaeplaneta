import ghidra.app.script.GhidraScript;
import ghidra.framework.model.DomainFile;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Program;
import java.util.*;

// Copy one data type category of a sibling program (read only) into the current program under
// another category name: the engine structs, vtable structs and slot FunctionDefinitions of a
// twin build (TIRO -> XILINDRO). Each type of <srcCat> not excluded is added with its
// dependencies; whatever lands in <srcCat> is then moved to <dstCat> (an existing type of the
// same name in <dstCat> is replaced). Types outside <srcCat> (SDK structs, built-ins) resolve as usual.
// Args: <source program> <srcCat> <dstCat> [exclude regex]
//   e.g. /TIRO.EXE /tiro /xilindro '^(Crossbow|Target|Projectile|Arrow)(Vtbl)?(_.*)?$'
// Excluded types that are still pulled in as dependencies are reported (and kept).
public class XilindroCopyCategory extends GhidraScript {
	public void run() throws Exception {
		String[] a = getScriptArgs();
		CategoryPath src = new CategoryPath(a[1]), dst = new CategoryPath(a[2]);
		java.util.regex.Pattern ex = a.length > 3 ? java.util.regex.Pattern.compile(a[3]) : null;
		DomainFile df = state.getProject().getProjectData().getFile(a[0]);
		Program sp = (Program) df.getReadOnlyDomainObject(this, -1, monitor);
		try {
			DataTypeManager td = currentProgram.getDataTypeManager();
			Category sc = sp.getDataTypeManager().getCategory(src);
			int added = 0, skipped = 0;
			for (DataType d : sc.getDataTypes()) {
				if (d instanceof Pointer || d instanceof Array) continue;
				if (ex != null && ex.matcher(d.getName()).find()) { skipped++; continue; }
				td.addDataType(d, DataTypeConflictHandler.REPLACE_HANDLER);
				added++;
			}
			Category from = td.getCategory(src);
			Category to = td.createCategory(dst);
			int moved = 0;
			List<String> pulled = new ArrayList<>();
			for (DataType d : from.getDataTypes()) {
				if (ex != null && ex.matcher(d.getName()).find() && !(d instanceof Pointer)) pulled.add(d.getName());
				DataType old = to.getDataType(d.getName());
				if (old != null && old != d) td.replaceDataType(old, d, false);
				to.moveDataType(d, DataTypeConflictHandler.REPLACE_HANDLER);
				moved++;
			}
			if (from.getDataTypes().length == 0 && from.getCategories().length == 0)
				from.getParent().removeCategory(from.getName(), monitor);
			println("added " + added + ", excluded " + skipped + ", moved to " + dst + " " + moved);
			if (!pulled.isEmpty()) println("excluded but pulled in as dependencies: " + pulled);
		}
		finally {
			sp.release(this);
		}
	}
}
