import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.reloc.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.util.*;

// Medium-model (far code, near data) vtables: turn every far vtable slot target into a function.
// Args: <data seg> <table lo> <table hi> [dry]     e.g. 1090 05d2 22a4
// A slot is a dword in DGROUP [lo,hi) whose segment word carries an NE relocation (the loader wrote
// the selector there) and whose value seg:off lands in an executable block. That is exact: the
// {0xfffe, k} vbtable rows and the plain data between tables carry no relocation. For each slot it:
//   - creates the target function (unless the target is inside another function: reported);
//   - types the slot as a 4-byte pointer (pointer32 resolves to seg:off, so the reference to the
//     code is the pointer's own), adding a DATA reference if the listing made none;
//   - adds a DATA reference from each vptr store (`MOV word ptr [r+k], imm`, imm a slot address in
//     [lo,hi), in any code block) to its table.
// Prints the tables (start, slot count, stores) and the targets it could not create.
public class FarVtSlots extends GhidraScript {
	public void run() throws Exception {
		String[] a = getScriptArgs();
		Memory mem = currentProgram.getMemory();
		Address data = toAddr(a[0] + ":0000");
		int lo = Integer.parseInt(a[1], 16), hi = Integer.parseInt(a[2], 16);
		boolean dry = a.length > 3 && a[3].equals("dry");
		RelocationTable rt = currentProgram.getRelocationTable();
		ReferenceManager rm = currentProgram.getReferenceManager();
		TreeMap<Integer, Address> slots = new TreeMap<>();
		for (int off = lo; off + 3 < hi; off += 2) {
			Address s = data.add(off);
			if (!rt.hasRelocation(s.add(2))) continue;
			int o = mem.getShort(s) & 0xffff, seg = mem.getShort(s.add(2)) & 0xffff;
			Address t;
			try { t = toAddr(String.format("%04x:%04x", seg, o)); }
			catch (Exception e) { continue; }
			MemoryBlock b = t == null ? null : mem.getBlock(t);
			if (b == null || !b.isExecute()) { println("slot " + s + " -> " + t + " not code"); continue; }
			slots.put(off, t);
		}
		// vptr stores in every code block
		Map<Integer, List<Address>> st = new TreeMap<>();
		for (Instruction in : currentProgram.getListing().getInstructions(true)) {
			if (!in.getMnemonicString().equals("MOV") || in.getNumOperands() != 2) continue;
			if ((in.getOperandType(1) & ghidra.program.model.lang.OperandType.SCALAR) == 0) continue;
			if (!in.toString().startsWith("MOV word ptr")) continue;
			Scalar sc = in.getScalar(1);
			if (sc == null) continue;
			int v = (int) sc.getUnsignedValue();
			if (slots.containsKey(v)) st.computeIfAbsent(v, k -> new ArrayList<>()).add(in.getAddress());
		}
		Set<Address> targets = new TreeSet<>(slots.values());
		int made = 0;
		List<String> inside = new ArrayList<>(), failed = new ArrayList<>();
		for (Address t : targets) {
			if (getFunctionAt(t) != null) continue;
			Function c = getFunctionContaining(t);
			if (c != null) { inside.add(t + " in " + c.getName()); continue; }
			if (dry) { made++; continue; }
			if (getInstructionAt(t) == null) disassemble(t);
			if (createFunction(t, null) != null) made++;
			else failed.add(t.toString());
		}
		if (!dry) {
			DataType p32 = new PointerDataType(VoidDataType.dataType, 4, currentProgram.getDataTypeManager());
			for (Map.Entry<Integer, Address> e : slots.entrySet()) {
				Address s = data.add(e.getKey());
				Data d = getDataAt(s);
				if (d == null || !d.isDefined() || d.getLength() != 4 || !(d.getDataType() instanceof Pointer)) {
					Data c = getDataContaining(s);
					if (c != null && c.isDefined()) clearListing(c.getAddress(), c.getMaxAddress());
					clearListing(s, s.add(3));
					createData(s, p32);
				}
				boolean has = false;
				for (Reference r : rm.getReferencesFrom(s)) if (r.getToAddress().equals(e.getValue())) has = true;
				if (!has) rm.addMemoryReference(s, e.getValue(), RefType.DATA, SourceType.USER_DEFINED, 0);
			}
			for (Map.Entry<Integer, List<Address>> e : st.entrySet())
				for (Address ia : e.getValue())
					rm.addMemoryReference(ia, data.add(e.getKey()), RefType.DATA, SourceType.USER_DEFINED, 1);
		}
		StringBuilder sb = new StringBuilder();
		// a table starts at a vptr store target, or after a gap in the slots; it ends at a gap or the next store
		Integer start = null, prev = null;
		List<Integer> keys = new ArrayList<>(slots.keySet());
		keys.add(Integer.MAX_VALUE);
		int n = 0;
		for (int k : keys) {
			boolean brk = start == null || k != prev + 4 || st.containsKey(k);
			if (brk && start != null) {
				sb.append(String.format("table %04x slots %d stores %s\n", start, n, st.getOrDefault(start, List.of())));
				n = 0;
			}
			if (brk) start = k;
			n++;
			prev = k;
		}
		println(sb.toString());
		println(String.format("slots %d, targets %d, functions %s %d, stores %d", slots.size(), targets.size(),
			dry ? "to create" : "created", made, st.values().stream().mapToInt(List::size).sum()));
		for (String s : inside) println("inside " + s);
		for (String s : failed) println("failed " + s);
	}
}
