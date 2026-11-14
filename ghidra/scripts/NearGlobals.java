import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Data;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
// Defines typed (and optionally named) globals. Near pointers are 2 bytes ("T*"); a near pointer
// to data stays in the data segment, so its default reference is right (unlike code pointers).
// Args: <category> <spec>; spec "seg:off:name:type;..." ("-" as name keeps the current label).
// Types as in NearStructs: base names (category first), "T*", "T*32", "T[n]", "T[n][m]".
// The covered range is cleared first, so a global may swallow stale undefined items.
public class NearGlobals extends GhidraScript {
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
  int ok = 0;
  for (String e : a[1].split(";")) {
   if (e.isBlank()) continue;
   String[] p = e.trim().split(":", 4);
   Address at = toAddr(p[0] + ":" + p[1]);
   DataType t = resolve(p[3]);
   clearListing(at, at.add(t.getLength() - 1));
   Data d = createData(at, t);
   if (!p[2].equals("-")) {
    Symbol s = getSymbolAt(at);
    if (s != null && s.getSource() != SourceType.DEFAULT) s.setName(p[2], SourceType.USER_DEFINED);
    else createLabel(at, p[2], true, SourceType.USER_DEFINED);
   }
   println(at + " " + p[2] + " " + d.getDataType().getName() + " len=" + Integer.toHexString(d.getLength()));
   ok++;
  }
  println("defined " + ok);
 }
}
