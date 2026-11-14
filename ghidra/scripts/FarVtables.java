import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.*;
// Medium-model vtables (TIRO): the vptr is a near pointer into DGROUP, but each slot is a 4-byte far
// code pointer (offset, then the NE-relocated segment). Far variant of NearVtables. The one spec
// argument holds entries separated by ';' (no spaces anywhere):
//   S|Name|field,field,...|tbl/tbl...   vtable struct /<cat>/Name: one 4-byte pointer per field to a
//                                       FunctionDefinition "Name_fieldFn" copied from the target of
//                                       that slot in the first listed table (hex DGROUP offsets) whose
//                                       target is a function other than _purecall
//   P|Name|field:type,...               plain unpacked struct (types: word, short, int, byte...)
//   A|off|Name|label                    apply struct Name at DGROUP:off, replace each slot's references
//                                       by one DATA reference to its seg:off target, set the label
//                                       ("-" = keep)
// Leading args: <category> <dataseg>, e.g. "/tiro 1090".
public class FarVtables extends GhidraScript {
 DataTypeManager dtm; CategoryPath cat; String ds;
 DataType findType(String n) {
  DataType t = dtm.getDataType(cat, n);
  if (t != null) return t;
  java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(n, l);
  if (!l.isEmpty()) return l.get(0);
  return BuiltInDataTypeManager.getDataTypeManager().getDataType(new CategoryPath("/"), n);
 }
 Address slotTarget(Address s) throws Exception {
  int o = getShort(s) & 0xffff, seg = getShort(s.add(2)) & 0xffff;
  if (o == 0 && seg == 0) return null;
  return toAddr(String.format("%04x:%04x", seg, o));
 }
 public void run() throws Exception {
  String[] a = getScriptArgs();
  cat = new CategoryPath(a[0]); ds = a[1];
  dtm = currentProgram.getDataTypeManager();
  ReferenceManager rm = currentProgram.getReferenceManager();
  for (String e : a[2].split(";")) {
   if (e.isBlank()) continue;
   String[] p = e.trim().split("\\|");
   if (p[0].equals("S")) {
    String[] fields = p[2].split(",");
    String[] tbls = p[3].split("/");
    StructureDataType s = new StructureDataType(cat, p[1], 0, dtm);
    s.setPackingEnabled(false);
    for (int i = 0; i < fields.length; i++) {
     Function f = null;
     for (String t : tbls) {
      Address tg = slotTarget(toAddr(ds + ":" + t).add(4 * i));
      Function g = tg == null ? null : getFunctionAt(tg);
      if (g != null && !g.getName().equals("_purecall")) { f = g; break; }
     }
     DataType target;
     if (f != null) {
      FunctionDefinitionDataType fd = new FunctionDefinitionDataType(f, false);
      fd.setName(p[1] + "_" + fields[i] + "Fn");
      fd.setCategoryPath(cat);
      target = dtm.addDataType(fd, DataTypeConflictHandler.REPLACE_HANDLER);
     } else {
      target = VoidDataType.dataType;
      println("WARN no target for " + p[1] + "." + fields[i]);
     }
     s.add(new PointerDataType(target, 4, dtm), fields[i], null);
    }
    DataType r = dtm.addDataType(s, DataTypeConflictHandler.REPLACE_HANDLER);
    println("struct " + r.getPathName() + " size=" + Integer.toHexString(r.getLength()));
   } else if (p[0].equals("P")) {
    StructureDataType s = new StructureDataType(cat, p[1], 0, dtm);
    s.setPackingEnabled(false);
    for (String f : p[2].split(",")) { String[] q = f.split(":"); s.add(findType(q[1]), q[0], null); }
    DataType r = dtm.addDataType(s, DataTypeConflictHandler.REPLACE_HANDLER);
    println("struct " + r.getPathName() + " size=" + r.getLength());
   } else if (p[0].equals("A")) {
    Address at = toAddr(ds + ":" + p[1]);
    DataType t = findType(p[2]);
    if (t == null) { println("NOTYPE " + e); continue; }
    clearListing(at, at.add(t.getLength() - 1));
    Data d = createData(at, t);
    int fixed = 0;
    for (int i = 0; i < d.getNumComponents(); i++) {
     Data c = d.getComponent(i);
     Address ca = c.getAddress();
     if (!(c.getDataType() instanceof Pointer)) continue;
     for (Reference r : rm.getReferencesFrom(ca)) rm.delete(r);
     Address tgt = slotTarget(ca);
     if (tgt != null) {
      rm.addMemoryReference(ca, tgt, RefType.DATA, SourceType.USER_DEFINED, 0);
      if (getFunctionAt(tgt) == null) println("WARN " + ca + " -> " + tgt + " is not a function start");
      fixed++;
     }
    }
    if (!p[3].equals("-")) {
     Symbol s = getSymbolAt(at);
     if (s != null && s.getSource() != SourceType.DEFAULT) s.setName(p[3], SourceType.USER_DEFINED);
     else createLabel(at, p[3], true, SourceType.USER_DEFINED);
    }
    println("apply " + at + " " + p[2] + " len=" + Integer.toHexString(d.getLength()) + " refs=" + fixed + " " + p[3]);
   }
  }
 }
}
