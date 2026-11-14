import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.*;
// Small-model vtables: near (2-byte) code pointers into the code segment, stored in DGROUP.
// A 2-byte pointer in DGROUP resolves to DGROUP:off, not to code, so after applying a vtable
// struct this script deletes the bogus DGROUP references of each slot and adds a DATA
// reference to <codeseg>:<value> instead. Entries of the one argument, separated by ';':
//   S|Name|field,field,...|tbl/tbl...   vtable struct /<cat>/Name, one near pointer per field to a
//                                       FunctionDefinition "Name_fieldFn" copied from the target of
//                                       that slot in the first listed table (hex DGROUP offsets)
//                                       whose word is not 0 (a pure virtual slot holds 0)
//   P|Name|field:type,...               plain unpacked struct (types: word, short, int, byte...)
//   A|off|Name|label                    apply struct Name at DGROUP:off, fix the slot references,
//                                       set the label ("-" = keep)
// Leading args: <category> <codeseg> <dataseg>, e.g. "/encaixe 1008 1018".
public class NearVtables extends GhidraScript {
 DataTypeManager dtm; CategoryPath cat; String cs, ds;
 DataType findType(String n) {
  DataType t = dtm.getDataType(cat, n);
  if (t != null) return t;
  java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(n, l);
  if (!l.isEmpty()) return l.get(0);
  return BuiltInDataTypeManager.getDataTypeManager().getDataType(new CategoryPath("/"), n);
 }
 public void run() throws Exception {
  String[] a = getScriptArgs();
  cat = new CategoryPath(a[0]); cs = a[1]; ds = a[2];
  dtm = currentProgram.getDataTypeManager();
  ReferenceManager rm = currentProgram.getReferenceManager();
  for (String e : a[3].split(";")) {
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
      int v = getShort(toAddr(ds + ":" + t).add(2 * i)) & 0xffff;
      if (v != 0) { f = getFunctionAt(toAddr(cs + ":" + Integer.toHexString(v))); break; }
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
     s.add(new PointerDataType(target, 2, dtm), fields[i], null);
    }
    DataType r = dtm.addDataType(s, DataTypeConflictHandler.REPLACE_HANDLER);
    println("struct " + r.getPathName() + " size=" + r.getLength());
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
     for (Reference r : rm.getReferencesFrom(ca)) rm.delete(r);
     if (c.getDataType() instanceof Pointer) {
      int v = getShort(ca) & 0xffff;
      if (v != 0) {
       Address tgt = toAddr(cs + ":" + Integer.toHexString(v));
       rm.addMemoryReference(ca, tgt, RefType.DATA, SourceType.USER_DEFINED, 0);
       if (getFunctionAt(tgt) == null) println("WARN " + ca + " -> " + tgt + " is not a function start");
       fixed++;
      }
     }
    }
    if (!p[3].equals("-")) {
     Symbol s = getSymbolAt(at);
     if (s != null && s.getSource() != SourceType.DEFAULT) s.setName(p[3], SourceType.USER_DEFINED);
     else createLabel(at, p[3], true, SourceType.USER_DEFINED);
    }
    println("apply " + at + " " + p[2] + " len=" + d.getLength() + " refs=" + fixed + " " + p[3]);
   }
  }
 }
}
