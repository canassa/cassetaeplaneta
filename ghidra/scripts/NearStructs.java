import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
// Near-model (small/medium) variant of NoiteStructs: builds unpacked structs of a fixed size in a
// category, fields placed at explicit offsets, gaps left undefined. Two passes, so structs can
// point at each other: first every struct is created (or resized) empty, then filled.
// Args: <category> <spec>; spec "Name@size=off:name:type,off:name:type;Name2@size=..." (hex).
// Types: base names (looked up in the category, then anywhere, then built-ins), "T*" near
// pointer (2 bytes), "T*32" far pointer, "T[n]" / "T[n][m]" arrays. No spaces anywhere.
// Each run replaces the fields it lists and clears the rest of the struct.
public class NearStructs extends GhidraScript {
 DataTypeManager dtm; CategoryPath cat;
 DataType resolve(String t) throws Exception {
  t = t.trim();
  if (t.endsWith("]")) {
   int i = t.indexOf('[');
   DataType e = resolve(t.substring(0, i));
   String dims = t.substring(i);
   java.util.List<Integer> ns = new java.util.ArrayList<>();
   for (String d : dims.substring(1, dims.length() - 1).split("\\]\\[")) ns.add(Integer.parseInt(d));
   for (int k = ns.size() - 1; k >= 0; k--) e = new ArrayDataType(e, ns.get(k), e.getLength(), dtm);
   return e;
  }
  if (t.endsWith("*32")) return new PointerDataType(resolve(t.substring(0, t.length() - 3)), 4, dtm);
  if (t.endsWith("*")) return new PointerDataType(resolve(t.substring(0, t.length() - 1)), 2, dtm);
  DataType d = dtm.getDataType(cat, t);
  if (d != null) return d;
  java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(t, l);
  for (DataType x : l) if (x.getCategoryPath().isRoot()) return x;
  if (!l.isEmpty()) return l.get(0);
  DataType b = BuiltInDataTypeManager.getDataTypeManager().getDataType(new CategoryPath("/"), t);
  if (b == null) throw new Exception("unknown type " + t);
  return b;
 }
 public void run() throws Exception {
  String[] a = getScriptArgs();
  cat = new CategoryPath(a[0]);
  dtm = currentProgram.getDataTypeManager();
  String[] defs = a[1].split(";");
  for (String sd : defs) {
   if (sd.isBlank()) continue;
   String head = sd.split("=", 2)[0];
   String name = head.split("@")[0]; int size = Integer.parseInt(head.split("@")[1], 16);
   DataType ex = dtm.getDataType(cat, name);
   if (ex instanceof Structure) {
    Structure s = (Structure) ex;
    s.deleteAll(); s.setPackingEnabled(false); s.growStructure(size);
   } else {
    StructureDataType s = new StructureDataType(cat, name, size, dtm);
    s.setPackingEnabled(false);
    dtm.addDataType(s, DataTypeConflictHandler.REPLACE_HANDLER);
   }
  }
  for (String sd : defs) {
   if (sd.isBlank()) continue;
   String[] p = sd.split("=", 2);
   String name = p[0].split("@")[0];
   Structure s = (Structure) dtm.getDataType(cat, name);
   if (p.length > 1 && !p[1].isBlank())
    for (String f : p[1].split(",")) {
     String[] q = f.split(":", 3);
     int off = Integer.parseInt(q[0], 16);
     DataType t = resolve(q[2]);
     s.replaceAtOffset(off, t, t.getLength(), q[1], null);
    }
   println(s.getPathName() + " size=" + Integer.toHexString(s.getLength()) + " fields=" + s.getNumDefinedComponents());
  }
 }
}
