import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

// Sweep the bytes of a code block that no function covers.
// Args: <seg> [report file] [create]
// Lists every gap (start, end, size, first bytes, what is there: padding / data / instructions /
// undefined) and the prologue hits inside it. With `create`, makes a function at each hit:
//   PUSH BP; MOV BP,SP (55 8B EC)          ENTER n,0 (C8 xx xx 00)
//   far exported prologue (1E 58 90 45 55 8B EC, 8C D8 90 45 55 8B EC)
//   a gap start that has a CALL or DATA reference to it
// and repeats until nothing new appears.
public class CodeGapSweep extends GhidraScript {
	Memory mem;

	int b(Address a) throws MemoryAccessException { return mem.getByte(a) & 0xff; }

	boolean match(Address a, int... p) throws MemoryAccessException {
		for (int i = 0; i < p.length; i++) if (p[i] >= 0 && b(a.add(i)) != p[i]) return false;
		return true;
	}

	boolean prologue(Address a) {
		try {
			return match(a, 0x55, 0x8b, 0xec) || match(a, 0xc8, -1, -1, 0x00)
				|| match(a, 0x1e, 0x58, 0x90, 0x45, 0x55, 0x8b, 0xec)
				|| match(a, 0x8c, 0xd8, 0x90, 0x45, 0x55, 0x8b, 0xec);
		}
		catch (MemoryAccessException e) {
			return false;
		}
	}

	AddressSet gaps(MemoryBlock blk) {
		AddressSet s = new AddressSet(blk.getStart(), blk.getEnd());
		for (Function f : currentProgram.getFunctionManager().getFunctions(blk.getStart(), true)) {
			if (!blk.contains(f.getEntryPoint())) break;
			s.delete(f.getBody());
		}
		return s;
	}

	public void run() throws Exception {
		String[] a = getScriptArgs();
		mem = currentProgram.getMemory();
		MemoryBlock blk = mem.getBlock(toAddr(a[0] + ":0000"));
		boolean create = Arrays.asList(a).contains("create");
		ReferenceManager rm = currentProgram.getReferenceManager();
		int made = 0;
		for (int pass = 0; create && pass < 10; pass++) {
			int before = made;
			for (AddressRange r : gaps(blk)) {
				Address s = r.getMinAddress();
				List<Address> hits = new ArrayList<>();
				boolean refd = false;
				for (Reference ref : rm.getReferencesTo(s)) refd = true;
				if (refd || prologue(s)) hits.add(s);
				for (Address x = s.add(1); x.compareTo(r.getMaxAddress()) <= 0; x = x.add(1)) {
					if (!prologue(x)) continue;
					Instruction ic = getInstructionContaining(x);
					if (ic != null && !ic.getAddress().equals(x)) continue;
					if (getDataContaining(x) != null) continue;
					hits.add(x);
				}
				for (Address h : hits) {
					if (getFunctionContaining(h) != null) continue;
					if (getDataContaining(h) != null) continue;
					if (getInstructionAt(h) == null) disassemble(h);
					if (createFunction(h, null) != null) made++;
				}
			}
			println("pass " + pass + ": created " + (made - before));
			if (made == before) break;
		}
		StringBuilder sb = new StringBuilder();
		long total = 0;
		int n = 0;
		for (AddressRange r : gaps(blk)) {
			Address s = r.getMinAddress();
			long len = r.getLength();
			total += len;
			n++;
			int pad = 0, insn = 0, dat = 0;
			StringBuilder hex = new StringBuilder();
			for (Address x = s; x.compareTo(r.getMaxAddress()) <= 0; x = x.add(1)) {
				int v = b(x);
				if (hex.length() < 48) hex.append(String.format("%02x", v));
				if (v == 0 || v == 0x90 || v == 0xcc) pad++;
				if (getInstructionContaining(x) != null) insn++;
				if (getDataContaining(x) != null) dat++;
			}
			String what = pad == len ? "padding" : dat == len ? "data" : insn == len ? "instructions"
					: insn > 0 || dat > 0 ? String.format("mixed(insn %d, data %d)", insn, dat) : "undefined";
			sb.append(String.format("%s %s %d %s %s\n", s, r.getMaxAddress(), len, what, hex));
		}
		sb.append(String.format("gaps %d, bytes %d, functions created %d\n", n, total, made));
		if (a.length > 1 && !a[1].equals("create")) {
			try (PrintWriter w = new PrintWriter(new FileWriter(a[1]))) { w.print(sb); }
			println(String.format("gaps %d, bytes %d, functions created %d -> %s", n, total, made, a[1]));
		}
		else println(sb.toString());
	}
}
