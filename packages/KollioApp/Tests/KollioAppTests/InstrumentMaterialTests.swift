import Foundation
import Testing
@testable import KollioApp

/// The material an instrument is made of, given what the person asked for.
///
/// The design refuses one thing in particular: a control must never depend on
/// what is behind it in order to be found. That is the whole content of
/// "Reduce Transparency", and it is a decision, not a hope — which is why it is
/// a function that can be called in a test rather than a comment about the
/// system's behaviour.
@Suite("Instruments under a system accessibility setting")
struct InstrumentMaterialTests {
    @Test("A material is used when transparency is not reduced")
    func glassByDefault() {
        #expect(InstrumentMaterial.resolve(reduceTransparency: false) == .glass)
    }

    @Test("Reduced transparency means the control stops being see-through")
    func opaqueWhenTransparencyIsReduced() {
        // Not "a different glass". A material that samples what is behind it
        // cannot honour the request that started.
        #expect(InstrumentMaterial.resolve(reduceTransparency: true) == .opaque)
    }

    @Test("The fallback is the only material this repository draws itself")
    func theDrawnSurfaceIsTheException() {
        // Glass and glass prominent come from the platform. The opaque one is a
        // hand-drawn rectangle, so it is the only one that has to be justified,
        // and the justification is the setting above.
        #expect(InstrumentMaterial.opaque.isSystemMaterial == false)
        #expect(InstrumentMaterial.glass.isSystemMaterial)
        #expect(InstrumentMaterial.glassProminent.isSystemMaterial)
    }

    @Test("The decision is total: no setting produces nothing")
    func theDecisionIsTotal() {
        for reduce in [true, false] {
            let material = InstrumentMaterial.resolve(reduceTransparency: reduce)
            #expect(
                InstrumentMaterial.allCases.contains(material),
                "reduceTransparency=\(reduce) produced a material that does not exist"
            )
        }
    }
}
