import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
// Arg: spec "NAME=field:type,field:type;NAME2=..." ; types: base names, "T *32" far ptr, "T *" near ptr, "T[n]" arrays.
// Fields are laid out sequentially (packed). Existing types with the same name are replaced.
public class NoiteStructs extends GhidraScript {
 DataTypeManager dtm;
 DataType resolve(String t) throws Exception {
  t = t.trim();
  if (t.endsWith("]")) { int i = t.lastIndexOf('['); int n = Integer.parseInt(t.substring(i + 1, t.length() - 1)); DataType e = resolve(t.substring(0, i)); return new ArrayDataType(e, n, e.getLength(), dtm); }
  if (t.endsWith("*32")) return new PointerDataType(resolve(t.substring(0, t.length() - 3)), 4, dtm);
  if (t.endsWith("*")) return new PointerDataType(resolve(t.substring(0, t.length() - 1)), 2, dtm);
  java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(t, l);
  for (DataType d : l) if (d.getCategoryPath().isRoot()) return d;
  if (!l.isEmpty()) return l.get(0);
  DataType b = BuiltInDataTypeManager.getDataTypeManager().getDataType(new CategoryPath("/"), t);
  if (b == null) throw new Exception("unknown type " + t);
  return b;
 }
 public void run() throws Exception {
  dtm = currentProgram.getDataTypeManager();
  for (String sd : getScriptArgs()[0].split(";")) {
   String[] p = sd.split("=", 2);
   StructureDataType s = new StructureDataType(CategoryPath.ROOT, p[0], 0, dtm);
   s.setPackingEnabled(false);
   for (String f : p[1].split(",")) { String[] q = f.split(":", 2); s.add(resolve(q[1]), q[0], null); }
   DataType r = dtm.addDataType(s, DataTypeConflictHandler.REPLACE_HANDLER);
   println(r.getName() + " size=" + r.getLength());
  }
 }
}
