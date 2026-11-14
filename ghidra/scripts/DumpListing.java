import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.mem.*;
import java.io.*;
// Dumps every instruction (addr, function entry, text, operand sizes, refs) and every defined data
// item of the program to two TSVs for offline analysis. Args: <outdir>
public class DumpListing extends GhidraScript {
 public void run() throws Exception {
  String out = getScriptArgs()[0];
  Listing l = currentProgram.getListing();
  ReferenceManager rm = currentProgram.getReferenceManager();
  try (PrintWriter w = new PrintWriter(new FileWriter(out + "/insns.tsv"))) {
   for (Instruction i : l.getInstructions(true)) {
    Function f = getFunctionContaining(i.getAddress());
    StringBuilder rs = new StringBuilder();
    for (Reference r : i.getReferencesFrom()) rs.append(r.getToAddress()).append('=').append(r.getReferenceType()).append(' ');
    w.println(i.getAddress() + "\t" + (f == null ? "-" : f.getEntryPoint().toString()) + "\t" + i.toString() + "\t" + i.getLength() + "\t" + rs.toString().trim());
   }
  }
  try (PrintWriter w = new PrintWriter(new FileWriter(out + "/data.tsv"))) {
   for (Data d : l.getDefinedData(true)) {
    Symbol s = getSymbolAt(d.getAddress());
    w.println(d.getAddress() + "\t" + d.getLength() + "\t" + d.getDataType().getPathName() + "\t" + (s == null ? "-" : s.getName()) + "\t" + d.getReferenceIteratorTo().hasNext());
   }
  }
  println("done");
 }
}
