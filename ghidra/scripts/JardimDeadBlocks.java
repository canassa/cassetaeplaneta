// Unreferenced code blocks after an unconditional JMP inside a function (/Od keeps the dead arm of a
// constant condition): disassemble each listed start and add the new instructions to the function that
// contains the previous instruction. Args: seg:off ...
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
public class JardimDeadBlocks extends GhidraScript {
	public void run() throws Exception {
		for (String s : getScriptArgs()) {
			Address a = toAddr(s);
			Instruction prev = getInstructionBefore(a);
			Function f = getFunctionContaining(prev.getAddress());
			disassemble(a);
			AddressSet add = new AddressSet();
			for (Instruction in = getInstructionAt(a); in != null && getFunctionContaining(in.getAddress()) == null; in = in.getNext())
				add.add(in.getAddress(), in.getMaxAddress());
			AddressSet body = new AddressSet(f.getBody());
			body.add(add);
			f.setBody(body);
			println(s + " -> " + f.getName() + " +" + add.getNumAddresses());
		}
	}
}
