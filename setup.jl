# Create a register net of N registers, each with M qubit slots. Connect them in a chain.
using QuantumSavory, QuantumSavory.ProtocolZoo, QuantumSavory.CircuitZoo
using Logging
using ConcurrentSim: Simulation, @yield, timeout, @process, now
import ConcurrentSim: Process

import ResumableFunctions
using ResumableFunctions: @resumable




const perfect_pair = (Z₁ ⊗ Z₁ + Z₂ ⊗ Z₂) / sqrt(2)
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

    # install entanglement trackers
    @process EntanglementTracker(sim, net, 1)()
    @process EntanglementTracker(sim, net, 2)()
    @process EntanglementTracker(sim, net, 3)()

    # Entangler for AB using the first twenty slots of B
    entangler_AB = EntanglerProt(sim, net, 1, 2; pairstate=pairstate,
    chooseslotB= <=(20), retry_lock_time=nothing, rounds=-1)
    @process entangler_AB()

    # Entangler for BC using the last ten slots of B
    entangler_BC = EntanglerProt(sim, net, 2, 3; pairstate=pairstate,
    chooseslotA= >(20), retry_lock_time=nothing, rounds=-1)
    @process entangler_BC()

    swapper_B = SwapperProt(sim, net, 2; nodeL=1, nodeH=3,
                chooseslots= (x) -> 11 <= x <= 30, retry_lock_time=nothing)
    @process swapper_B()

    distiller_AC = BBPPSWProt(net, 1, 3)
    @process distiller_AC()

    return sim, net
end



global_logger(SimpleLogger(stderr, Logging.Debug))

sim, net = setup()
run(sim, 100)
