// PlaceholderEntityFactory.swift
#if os(visionOS)
// Factory for creating and managing the floor placement placeholder marker.

import UIKit
import RealityKit

// MARK: - Placeholder Entity Factory

/// Factory for creating and managing the floor placement placeholder marker.
/// Creates a hexagon grid that pulses to indicate where the level will be placed.
@MainActor
enum PlaceholderEntityFactory {
    
    /// Creates the hexagon grid placeholder marker for level placement.
    /// - Parameter reduceMotion: When `true`, the pulsing animation is skipped for accessibility.
    static func createPlaceholderMarker(reduceMotion: Bool = false) -> Entity {
        let markerEntity = Entity()
        markerEntity.name = "LevelPlaceholder"
        
        // Hexagon grid parameters
        let hexRadius: Float = 0.08
        let hexSpacing: Float = 0.18
        let hexHeight: Float = 0.004
        let baseY: Float = 0.002
        
        // Materials with varying opacity for depth effect
        var centerMaterial = UnlitMaterial()
        centerMaterial.color = .init(tint: .white.withAlphaComponent(0.95))
        centerMaterial.faceCulling = .none
        
        var innerMaterial = UnlitMaterial()
        innerMaterial.color = .init(tint: .white.withAlphaComponent(0.7))
        innerMaterial.faceCulling = .none
        
        var outerMaterial = UnlitMaterial()
        outerMaterial.color = .init(tint: .white.withAlphaComponent(0.45))
        outerMaterial.faceCulling = .none
        
        // Create container for all hexagons
        let gridEntity = Entity()
        gridEntity.name = "HexGrid"
        
        // Center hexagon (brightest)
        let centerHex = createHexagon(radius: hexRadius, height: hexHeight, material: centerMaterial, baseY: baseY)
        centerHex.name = "CenterHex"
        gridEntity.addChild(centerHex)
        
        // First ring of 6 hexagons around center
        let innerRingPositions: [SIMD2<Float>] = [
            [0, -hexSpacing],
            [hexSpacing * 0.866, -hexSpacing * 0.5],
            [hexSpacing * 0.866, hexSpacing * 0.5],
            [0, hexSpacing],
            [-hexSpacing * 0.866, hexSpacing * 0.5],
            [-hexSpacing * 0.866, -hexSpacing * 0.5]
        ]
        
        for (index, pos) in innerRingPositions.enumerated() {
            let hex = createHexagon(radius: hexRadius, height: hexHeight, material: innerMaterial, baseY: baseY)
            hex.name = "InnerHex_\(index)"
            hex.position = [pos.x, 0, pos.y]
            gridEntity.addChild(hex)
        }
        
        // Outer ring (12 hexagons)
        let outerRingPositions: [SIMD2<Float>] = [
            [0, -hexSpacing * 2],
            [hexSpacing * 0.866, -hexSpacing * 1.5],
            [hexSpacing * 1.732, -hexSpacing],
            [hexSpacing * 1.732, 0],
            [hexSpacing * 1.732, hexSpacing],
            [hexSpacing * 0.866, hexSpacing * 1.5],
            [0, hexSpacing * 2],
            [-hexSpacing * 0.866, hexSpacing * 1.5],
            [-hexSpacing * 1.732, hexSpacing],
            [-hexSpacing * 1.732, 0],
            [-hexSpacing * 1.732, -hexSpacing],
            [-hexSpacing * 0.866, -hexSpacing * 1.5]
        ]
        
        for (index, pos) in outerRingPositions.enumerated() {
            let hex = createHexagon(radius: hexRadius, height: hexHeight, material: outerMaterial, baseY: baseY)
            hex.name = "OuterHex_\(index)"
            hex.position = [pos.x, 0, pos.y]
            gridEntity.addChild(hex)
        }
        
        markerEntity.addChild(gridEntity)
        
        // Start pulsing animation (skip when Reduce Motion is enabled)
        if !reduceMotion {
            startHexagonPulseAnimation(for: markerEntity)
        }
        
        return markerEntity
    }
    
    /// Creates a single hexagon outline from 6 edge segments with rounded corners.
    private static func createHexagon(radius: Float, height: Float, material: UnlitMaterial, baseY: Float) -> Entity {
        let hexEntity = Entity()
        
        // Create corner mesh (flattened sphere) to join segments seamlessly
        let cornerRadius: Float = 0.004
        let cornerMesh = MeshResource.generateSphere(radius: cornerRadius)
        
        // Edge Cylinder: Scale to match the ellipsoid profile
        let edgeCylinderMesh = MeshResource.generateCylinder(height: radius, radius: cornerRadius)

        for i in 0..<6 {
            let angle = Float(i) * (.pi / 3) + (.pi / 6)
            let nextAngle = Float(i + 1) * (.pi / 3) + (.pi / 6)
            
            let x1 = radius * cos(angle)
            let z1 = radius * sin(angle)
            let x2 = radius * cos(nextAngle)
            let z2 = radius * sin(nextAngle)
            
            let centerX = (x1 + x2) / 2
            let centerZ = (z1 + z2) / 2
            let edgeAngle = atan2(z2 - z1, x2 - x1)
            
            // Create Edge Container (handles position and rotation in the plane)
            let edgeContainer = Entity()
            edgeContainer.position = [centerX, baseY, centerZ]
            edgeContainer.orientation = simd_quatf(angle: -edgeAngle, axis: [0, 1, 0])
            hexEntity.addChild(edgeContainer)
            
            // Create Edge Model (Cylinder rotated and scaled to form elliptical tube)
            let edge = ModelEntity(mesh: edgeCylinderMesh, materials: [material])
            edge.transform = Transform(
                scale: [0.5, 1.0, 1.0],
                rotation: simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]),
                translation: .zero
            )
            edgeContainer.addChild(edge)
            
            // Create Corner at the start of the edge (x1, z1)
            let corner = ModelEntity(mesh: cornerMesh, materials: [material])
            corner.position = [x1, baseY, z1]
            corner.scale = [1.0, 0.5, 1.0]
            hexEntity.addChild(corner)
        }
        
        return hexEntity
    }
    
    /// Starts the pulsing animation for the hexagon grid using a manual
    /// frame-by-frame loop — the same proven approach used in SpatialStepOperator.
    /// Directly sets `.scale` and `.orientation` each frame so that each entity's
    /// position is never overwritten by a transform animation.
    private static func startHexagonPulseAnimation(for marker: Entity) {
        Task { @MainActor in
            let startTime = Date()
            
            while marker.parent != nil || marker.name == "LevelPlaceholder" {
                guard marker.isEnabled else {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }
                
                let elapsed = Float(Date().timeIntervalSince(startTime))
                
                guard let grid = marker.findEntity(named: "HexGrid") else {
                    try? await Task.sleep(for: .milliseconds(50))
                    continue
                }
                
                // Pulse the center hexagon
                if let centerHex = grid.findEntity(named: "CenterHex") {
                    let centerPulse = 1.0 + sin(elapsed * 3.0) * 0.08
                    centerHex.scale = SIMD3<Float>(repeating: centerPulse)
                }
                
                // Pulse inner ring hexagons with wave delay
                for i in 0..<6 {
                    if let hex = grid.findEntity(named: "InnerHex_\(i)") {
                        let phase = Float(i) * (.pi / 3)
                        let pulse = 1.0 + sin(elapsed * 2.5 + phase) * 0.06
                        hex.scale = SIMD3<Float>(repeating: pulse)
                    }
                }
                
                // Pulse outer ring hexagons with slower wave
                for i in 0..<12 {
                    if let hex = grid.findEntity(named: "OuterHex_\(i)") {
                        let phase = Float(i) * (.pi / 6)
                        let pulse = 1.0 + sin(elapsed * 2.0 + phase + .pi / 2) * 0.04
                        hex.scale = SIMD3<Float>(repeating: pulse)
                    }
                }
                
                // Subtle rotation of entire grid
                let rotationAngle = elapsed * 0.1
                grid.orientation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
                
                try? await Task.sleep(for: .milliseconds(16))  // ~60fps
            }
        }
    }
}
#endif
