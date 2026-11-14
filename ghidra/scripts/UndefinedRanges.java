import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.MemoryBlock;
// Lists the runs of undefined bytes in one memory block, with their bytes (first 16) and whether
// anything references them; also lists defined data still typed undefined1/2/4.
// Args: <seg:off of any address in the block>
public class UndefinedRanges extends GhidraScript {
 public void run() throws Exception {
  Address any = toAddr(getScriptArgs()[0]);
  MemoryBlock b = currentProgram.getMemory().getBlock(any);
  Listing l = currentProgram.getListing();
  Address a = b.getStart(), runStart = null;
  int total = 0;
  while (a != null && a.compareTo(b.getEnd()) <= 0) {
   CodeUnit cu = l.getCodeUnitAt(a);
   boolean undef = cu instanceof Data && !((Data) cu).isDefined();
   if (undef && runStart == null) runStart = a;
   if ((!undef || a.equals(b.getEnd())) && runStart != null) {
    Address end = undef ? a : a.subtract(1);
    int n = (int) (end.subtract(runStart) + 1);
    total += n;
    StringBuilder sb = new StringBuilder();
    boolean refd = false;
    for (int i = 0; i < n; i++) {
     Address x = runStart.add(i);
     if (i < 16) { try { sb.append(String.format("%02x", getByte(x) & 0xff)); } catch (Exception e) { sb.append("??"); } }
     if (currentProgram.getReferenceManager().hasReferencesTo(x)) refd = true;
    }
    println(runStart + "-" + end + " " + Integer.toHexString(n) + (refd ? " REF" : "") + " " + sb);
    runStart = null;
   }
   a = cu == null ? a.add(1) : cu.getMaxAddress().add(1);
  }
  println("undefined bytes: " + Integer.toHexString(total));
  for (Data d : l.getDefinedData(b.getStart(), true)) {
   if (d.getAddress().compareTo(b.getEnd()) > 0) break;
   String n = d.getDataType().getName();
   if (n.startsWith("undefined")) println("STALE " + d.getAddress() + " " + n);
  }
 }
}
