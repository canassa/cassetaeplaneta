import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.util.*;

// Small-model (near) vtables: turn every vtable slot target into a function.
// Args: <code seg> <data seg> <table lo> <table hi> [min target] [dry]
//   e.g. 1008 1018 0300 1090 2000
// A DGROUP word in [lo,hi) is a slot when its value is a code offset >= min target whose first bytes
// look like a method start (PUSH BP / ENTER / XOR AX,AX / MOV AX,imm / MOV AX,[m] / RET n / RET /
// MOV BX,SP of an adjustor thunk) and that is not inside an instruction or a data item of the code
// segment or another function, and not the second word of a {0xfffe, offset} vbtable row (negative
// vbase offsets such as 0xfb92 land in code). Slots are kept when they form a run of >= 3, or a run starting at a vptr store
// (`MOV word ptr [r+k], imm` with imm in [lo,hi)). The script iterates until no new store appears.
// For each slot it: creates the target function, types the slot as `word` (a 2-byte pointer would
// resolve into DGROUP), adds a DATA reference slot -> code target, and adds a DATA reference from each
// vptr store's immediate to the table. Prints the tables (store address, table, slot count).
public class NearVtSlots extends GhidraScript {
	Memory mem;
	Address code, data;
	long codeEnd, minTarget;
	int codeSel; // the code segment selector value (e.g. 0x1008) is a far-pointer segment, never a table

	boolean plausible(int w) throws Exception {
		if (w < minTarget || w >= codeEnd) return false;
		Address t = code.add(w);
		if (getFunctionAt(t) != null) return true;
		Instruction ic = getInstructionContaining(t);
		if (ic != null && !ic.getAddress().equals(t)) return false;
		if (getDataContaining(t) != null) return false;
		if (getFunctionContaining(t) != null) return false; // inside another function: a tail, not a method
		int b0 = mem.getByte(t) & 0xff, b1 = mem.getByte(t.add(1)) & 0xff;
		switch (b0) {
			case 0x55: return b1 == 0x8b;              // PUSH BP; MOV BP,SP
			case 0xc8: return true;                     // ENTER
			case 0x33: return b1 == 0xc0;              // XOR AX,AX
			case 0xb8: case 0xa1: case 0xc2: case 0xc3: return true;
			case 0x8b: return b1 == 0xdc;              // MOV BX,SP (adjustor thunk)
			default: return false;
		}
	}

	int word(int off) throws Exception { return mem.getShort(data.add(off)) & 0xffff; }

	// vptr stores in existing functions: imm -> list of instruction addresses
	Map<Integer, List<Address>> stores(int lo, int hi) {
		Map<Integer, List<Address>> m = new TreeMap<>();
		for (Instruction in : currentProgram.getListing().getInstructions(code, true)) {
			if (!in.getAddress().getAddressSpace().equals(code.getAddressSpace())) break;
			if (in.getMinAddress().getOffset() >= code.getOffset() + codeEnd) break;
			if (!in.getMnemonicString().equals("MOV") || in.getNumOperands() != 2) continue;
			if (in.getLength() < 4) continue;
			Scalar s = in.getScalar(1);
			if (s == null || (in.getOperandType(1) & ghidra.program.model.lang.OperandType.SCALAR) == 0) continue;
			if (!in.toString().startsWith("MOV word ptr")) continue;
			int v = (int) s.getUnsignedValue();
			if (v >= lo && v < hi && v != codeSel && v % 2 == 0) m.computeIfAbsent(v, k -> new ArrayList<>()).add(in.getAddress());
		}
		return m;
	}

	public void run() throws Exception {
		String[] a = getScriptArgs();
		mem = currentProgram.getMemory();
		code = toAddr(a[0] + ":0000");
		data = toAddr(a[1] + ":0000");
		int lo = Integer.parseInt(a[2], 16), hi = Integer.parseInt(a[3], 16);
		minTarget = a.length > 4 ? Long.parseLong(a[4], 16) : 0;
		boolean dry = a.length > 5 && a[5].equals("dry");
		codeEnd = mem.getBlock(code).getSize();
		codeSel = Integer.parseInt(a[0], 16);
		ReferenceManager rm = currentProgram.getReferenceManager();
		Set<Integer> slots = new TreeSet<>();
		Set<Integer> created = new TreeSet<>();
		List<String> failed = new ArrayList<>();
		Map<Integer, List<Address>> st = new TreeMap<>();
		for (int pass = 0; pass < 8; pass++) {
			st = stores(lo, hi);
			boolean[] ok = new boolean[hi];
			for (int off = lo; off + 1 < hi; off += 2)
				ok[off] = plausible(word(off)) && !(off >= lo + 2 && word(off - 2) == 0xfffe); // {-2, vbase offset} is a vbtable row
			Set<Integer> now = new TreeSet<>();
			for (int off = lo; off + 1 < hi;) {
				if (!ok[off]) { off += 2; continue; }
				int e = off;
				while (e + 1 < hi && ok[e]) e += 2;
				boolean stored = false;
				for (int o = off; o < e; o += 2) if (st.containsKey(o)) stored = true;
				if ((e - off) / 2 >= 3 || stored) for (int o = off; o < e; o += 2) now.add(o);
				off = e;
			}
			int before = created.size();
			for (int off : now) {
				slots.add(off);
				int w = word(off);
				Address t = code.add(w);
				if (getFunctionAt(t) != null || created.contains(w)) continue;
				if (dry) { created.add(w); continue; }
				if (getInstructionAt(t) == null) disassemble(t);
				Function f = createFunction(t, null);
				if (f == null) failed.add(String.format("%04x->%04x", off, w));
				else created.add(w);
			}
			println("pass " + pass + ": slots " + slots.size() + ", stores " + st.size() + ", new functions "
				+ (created.size() - before));
			if (created.size() == before) break;
		}
		if (!dry) {
			for (int off : slots) {
				Address s = data.add(off);
				Data d = getDataAt(s);
				if (d == null || !d.isDefined() || d.getLength() != 2) {
					Data c = getDataContaining(s);
					if (c != null && c.isDefined()) {
						println("clearing " + c.getAddress() + " " + c.getDataType().getName() + " over slot " + s);
						clearListing(c.getAddress(), c.getMaxAddress());
					}
					clearListing(s, s.add(1));
					createData(s, WordDataType.dataType);
				}
				rm.addMemoryReference(s, code.add(word(off)), RefType.DATA, SourceType.USER_DEFINED, 0);
			}
			for (Map.Entry<Integer, List<Address>> e : st.entrySet())
				for (Address ia : e.getValue())
					rm.addMemoryReference(ia, data.add(e.getKey()), RefType.DATA, SourceType.USER_DEFINED, 1);
		}
		StringBuilder sb = new StringBuilder();
		// tables: a store target starts a table; it runs over consecutive slots
		for (int t : st.keySet()) {
			int n = 0;
			for (int o = t; slots.contains(o) && (o == t || !st.containsKey(o)); o += 2) n++;
			sb.append(String.format("table %04x slots %d stores", t, n));
			for (Address ia : st.get(t)) sb.append(" ").append(ia);
			sb.append("\n");
		}
		println(sb.toString());
		println("slots " + slots.size() + ", functions created " + created.size() + ", failed " + failed);
	}
}
