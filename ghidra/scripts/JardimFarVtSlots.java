// Large-model (far code, far data) vtables kept in a code segment (JARDIM: 10c0, like NOITE's 1018).
// The vptr is a far pointer stored as two words: MOV word ptr [r+k],off ... MOV word ptr [r+k+2],seg with
// the seg immediate NE-relocated to a code block. Each such store names a table start; the table runs on
// while the next dword's segment word carries a relocation and points into a code block (a vbtable has
// no relocated word, so it gets no slot). Extra table starts can be listed as args (seg:off).
// For each slot: create the target function, type the slot as a 4-byte pointer (DATA reference to the
// code), and add a DATA reference from every store instruction to its table.
// Args: [dry] [seg:off ...]
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.reloc.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.util.*;

public class JardimFarVtSlots extends GhidraScript {
	public void run() throws Exception {
		String[] a = getScriptArgs();
		boolean dry = false;
		RelocationTable rt = currentProgram.getRelocationTable();
		Memory mem = currentProgram.getMemory();
		ReferenceManager rm = currentProgram.getReferenceManager();
		TreeMap<Address, List<Address>> st = new TreeMap<>();
		for (String s : a) { if (s.equals("dry")) dry = true; else st.computeIfAbsent(toAddr(s), x -> new ArrayList<>()); }
		for (Instruction in : currentProgram.getListing().getInstructions(true)) {
			if (!in.getMnemonicString().equals("MOV") || !in.toString().startsWith("MOV word ptr")) continue;
			Scalar sc = in.getScalar(1);
			if (sc == null || !rt.hasRelocation(in.getAddress().add(in.getLength() - 2))) continue;
			Address segA;
			try { segA = toAddr(String.format("%04x:0000", sc.getUnsignedValue())); } catch (Exception e) { continue; }
			MemoryBlock b = mem.getBlock(segA);
			if (b == null || !b.isExecute()) continue;
			Instruction p = in.getPrevious();
			for (int i = 0; i < 4 && p != null; i++, p = p.getPrevious()) {
				if (p.getMnemonicString().equals("MOV") && p.toString().startsWith("MOV word ptr") && p.getScalar(1) != null
						&& (p.getOperandType(1) & ghidra.program.model.lang.OperandType.SCALAR) != 0
						&& !rt.hasRelocation(p.getAddress().add(p.getLength() - 2))) {
					Address t = segA.add(p.getScalar(1).getUnsignedValue());
					st.computeIfAbsent(t, x -> new ArrayList<>()).add(p.getAddress());
					break;
				}
			}
		}
		TreeMap<Address, Address> slots = new TreeMap<>();
		StringBuilder sb = new StringBuilder();
		for (Address t : st.keySet()) {
			int n = 0;
			for (Address s = t; ; s = s.add(4), n++) {
				if (!rt.hasRelocation(s.add(2))) break;
				if (n > 0 && st.containsKey(s)) break;
				int o = mem.getShort(s) & 0xffff, seg = mem.getShort(s.add(2)) & 0xffff;
				Address c;
				try { c = toAddr(String.format("%04x:%04x", seg, o)); } catch (Exception e) { break; }
				MemoryBlock b = mem.getBlock(c);
				if (b == null || !b.isExecute()) break;
				slots.put(s, c);
			}
			sb.append(String.format("table %s slots %d stores %s\n", t, n, st.get(t)));
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
		int fixed = 0;
		if (!dry) {
			DataType p32 = new PointerDataType(VoidDataType.dataType, 4, currentProgram.getDataTypeManager());
			for (Map.Entry<Address, Address> e : slots.entrySet()) {
				Address s = e.getKey();
				Data d = getDataAt(s);
				if (d == null || !d.isDefined() || d.getLength() != 4 || !(d.getDataType() instanceof Pointer)) {
					Instruction ci = getInstructionContaining(s);
					if (ci != null) { println("slot " + s + " over instruction " + ci.getAddress() + ", skipped"); continue; }
					Data c = getDataContaining(s);
					if (c != null && c.isDefined()) clearListing(c.getAddress(), c.getMaxAddress());
					clearListing(s, s.add(3));
					createData(s, p32);
					fixed++;
				}
				boolean has = false;
				for (Reference r : rm.getReferencesFrom(s)) if (r.getToAddress().equals(e.getValue())) has = true;
				if (!has) rm.addMemoryReference(s, e.getValue(), RefType.DATA, SourceType.USER_DEFINED, 0);
			}
			for (Map.Entry<Address, List<Address>> e : st.entrySet())
				for (Address ia : e.getValue())
					rm.addMemoryReference(ia, e.getKey(), RefType.DATA, SourceType.USER_DEFINED, 1);
		}
		println(sb.toString());
		println(String.format("tables %d, slots %d, targets %d, functions %s %d, slots typed %d", st.size(), slots.size(), targets.size(),
			dry ? "to create" : "created", made, fixed));
		for (String s : inside) println("inside " + s);
		for (String s : failed) println("failed " + s);
	}
}
