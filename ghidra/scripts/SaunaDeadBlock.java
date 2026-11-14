import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
// Args: seg:lo-seg:hi ...  unreachable code between two pieces of one function (after an unconditional JMP):
// disassemble it and add it to the function that contains the byte before it.
public class SaunaDeadBlock extends GhidraScript {
	public void run() throws Exception {
		for (String s : getScriptArgs()) {
			String[] p = s.split("-");
			Address lo = toAddr(p[0]), hi = toAddr(p[1]);
			Function f = getFunctionContaining(lo.subtract(1));
			Function g = getFunctionContaining(hi.add(1));
			if (f == null || f != g) { println("skip " + s + " (neighbours differ)"); continue; }
			disassemble(lo);
			AddressSet b = new AddressSet(f.getBody());
			b.add(lo, hi);
			f.setBody(b);
			println("added " + s + " to " + f.getName());
		}
	}
}
