# Create a register net of N registers, each with M qubit slots. Connect them in a chain.
using QuantumSavory, QuantumSavory.ProtocolZoo


const perfect_pair = (Z1Z1 + Z2Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
depolarized_pair(F) = F*perfect_pair_dm + (1-F)*mixed_dm 



function setup()

    A = Register(20)
    B = Register(30)
    C = Register(10)
    net = RegisterNet([A, B, C])
    sim = get_time_tracker(net)

    pairstate = depolarized_pair(0.99)

    # Entangler for AB using the first twenty slots of B
    entangler_AB = EntanglerProt(sim, net, 1, 2; pairstate=pairstate,
    chooseslotB= <=(20))
    @process entangler_AB()

    # Entangler for BC using the last ten slots of B
    entangler_BC = EntanglerProt(sim, net, 2, 3; pairstate=pairstate,
    chooseslotB= >(20))
    @process entangler_BC()

    swapper_B = SwapperProt(sim, net, 2; nodeL=1, nodeH=3,
                chooseslots= (x) -> 21 <= x <= 30)
    @process swapper_B()


struct DistilledTag end

# pick slots in reg without a DistilledTag
function nondistilled(reg)
    return (slots) -> begin
        dist = queryall(reg, DistilledTag)
        tagged = [d.slot.idx for d in dist]
        [s for s in slots if !(s in tagged)]
    end
end
distiller_AC = BBPPSWProt(sim, net, nodeA=1, nodeB=3, tag=DistilledTag, chooseA=nondistilled(A), chooseB=nondistilled(C))
@process distiller_AC()

end
