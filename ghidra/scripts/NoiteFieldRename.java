import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
// Arg: "Struct.old=new;Struct.old=new;..." renames struct fields directly.
public class NoiteFieldRename extends GhidraScript {
 public void run() throws Exception {
  DataTypeManager dtm = currentProgram.getDataTypeManager();
  for (String e : getScriptArgs()[0].split(";")) {
   String[] a = e.split("=", 2); String[] sf = a[0].split("\\.", 2);
   java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(sf[0], l);
   Structure s = null; for (DataType d : l) if (d instanceof Structure && d.getCategoryPath().isRoot()) s = (Structure) d;
   if (s == null) { println("NOSTRUCT " + sf[0]); continue; }
   boolean ok = false;
   for (DataTypeComponent c : s.getDefinedComponents()) if (sf[1].equals(c.getFieldName())) { c.setFieldName(a[1]); ok = true; }
   println((ok ? "OK " : "MISS ") + e);
  }
 }
}
