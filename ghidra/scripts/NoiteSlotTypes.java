import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.Function;
// Arg: "Vtbl@hexoff=seg:off;..." types the vtable struct field at hexoff as a far pointer to a
// function definition copied from the function at seg:off (name "<Vtbl>_<field>Fn"), keeping the
// field name. Gives indirect calls through that slot the right convention/params/stack purge.
public class NoiteSlotTypes extends GhidraScript {
 public void run() throws Exception {
  DataTypeManager dtm = currentProgram.getDataTypeManager();
  for (String e : getScriptArgs()[0].split(";")) {
   String[] a = e.split("=", 2); String[] so = a[0].split("@", 2);
   java.util.List<DataType> l = new java.util.ArrayList<>(); dtm.findDataTypes(so[0], l);
   Structure s = null; for (DataType d : l) if (d instanceof Structure && d.getCategoryPath().isRoot()) s = (Structure) d;
   if (s == null) { println("NOSTRUCT " + e); continue; }
   Function f = getFunctionAt(toAddr(a[1]));
   if (f == null) { println("NOFUNC " + e); continue; }
   int off = Integer.parseInt(so[1], 16);
   DataTypeComponent c = s.getComponentAt(off);
   String fname = c != null && c.getFieldName() != null ? c.getFieldName() : "slot" + so[1];
   FunctionDefinitionDataType fd = new FunctionDefinitionDataType(f, false);
   fd.setName(so[0] + "_" + fname + "Fn");
   DataType fdr = dtm.addDataType(fd, DataTypeConflictHandler.REPLACE_HANDLER);
   DataType p = new PointerDataType(fdr, 4, dtm);
   s.replaceAtOffset(off, p, 4, fname, c != null ? c.getComment() : null);
   println("OK " + e + " " + fdr.getName() + " = " + f.getSignature().getPrototypeString());
  }
 }
}
