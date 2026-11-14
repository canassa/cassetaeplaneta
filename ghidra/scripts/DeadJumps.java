import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import java.util.*;

// /Od builds (TIRO) leave an unreachable `JMP rel16` (E9 xx xx) right after an unconditional jump:
// the jump to the epilogue that ends a `case`/`return` the compiler had already left. No flow reaches
// it, so it stays undefined between two pieces of the same function. For every such 3-byte gap in
// the given code segments whose previous instruction is an unconditional JMP and whose both
// neighbours belong to one function, this disassembles the JMP and adds it to that function's body
// (the decompiler drops it as unreachable). A dead jump may be the target of another dead jump
// (a chain of them); any other reference to it rules it out. Args: <seg>... [dry]
public class DeadJumps extends GhidraScript {
	public void run() throws Exception {
		List<String> a = new ArrayList<>(Arrays.asList(getScriptArgs()));
		boolean dry = a.remove("dry");
		Memory mem = currentProgram.getMemory();
		int fixed = 0;
		List<String> odd = new ArrayList<>();
		for (String seg : a) {
			MemoryBlock blk = mem.getBlock(toAddr(seg + ":0000"));
			AddressSet gaps = new AddressSet(blk.getStart(), blk.getEnd());
			for (Function f : currentProgram.getFunctionManager().getFunctions(blk.getStart(), true)) {
				if (!blk.contains(f.getEntryPoint())) break;
				gaps.delete(f.getBody());
			}
			List<AddressRange> cand = new ArrayList<>();
			Set<Address> starts = new HashSet<>();
			for (AddressRange r : gaps) {
				Address s = r.getMinAddress();
				if (r.getLength() != 3 || (mem.getByte(s) & 0xff) != 0xe9) continue;
				if (s.equals(blk.getStart()) || r.getMaxAddress().equals(blk.getEnd())) continue;
				Function fb = getFunctionContaining(s.subtract(1)), fa = getFunctionContaining(s.add(3));
				Instruction prev = getInstructionContaining(s.subtract(1));
				if (fb == null || fb != fa || prev == null || !prev.getMnemonicString().equals("JMP")
						|| prev.getFlowType().isConditional()) {
					odd.add(s.toString());
					continue;
				}
				cand.add(r);
				starts.add(s);
			}
			for (AddressRange r : cand) {
				Address s = r.getMinAddress();
				boolean other = false;
				for (ghidra.program.model.symbol.Reference ref : getReferencesTo(s))
					if (!starts.contains(ref.getFromAddress())) other = true;
				if (other) { odd.add(s.toString()); continue; }
				Function fb = getFunctionContaining(s.subtract(1));
				fixed++;
				if (dry) continue;
				if (getInstructionAt(s) == null) disassemble(s);
				AddressSet body = new AddressSet(fb.getBody());
				body.add(s, r.getMaxAddress());
				fb.setBody(body);
			}
		}
		println("dead jumps " + (dry ? "found " : "added ") + fixed + ", skipped " + odd);
	}
}
