import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
// Arg: "Struct@hexoff=name:type;..." sets (replaces) the field at an offset of an unpacked struct.
// Types as in NoiteStructs: base names, "T*32" far ptr, "T*" near ptr, "T[n]" arrays (no spaces).
public class NoiteFieldSet extends GhidraScript {
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
  for (String e : getScriptArgs()[0].split(";")) {
   String[] a = e.split("=", 2); String[] so = a[0].split("@", 2); String[] nt = a[1].split(":", 2);
   java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(so[0], l);
   Structure s = null; for (DataType d : l) if (d instanceof Structure && d.getCategoryPath().isRoot()) s = (Structure) d;
   if (s == null) { println("NOSTRUCT " + e); continue; }
   int off = Integer.parseInt(so[1], 16); DataType t = resolve(nt[1]);
   s.replaceAtOffset(off, t, t.getLength(), nt[0], null);
   println("OK " + e + " len=" + t.getLength() + " size=" + s.getLength());
  }
 }
}
