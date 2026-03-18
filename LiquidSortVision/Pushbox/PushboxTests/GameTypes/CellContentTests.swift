// CellContentTests.swift
// Tests for CellContent enum computed properties.

import Testing
import RealityKit
@testable import Pushbox

@Suite("CellContent")
@MainActor
struct CellContentTests {

    // MARK: - isWalkable

    @Test("Empty cell is walkable")
    func emptyIsWalkable() {
        #expect(CellContent.empty.isWalkable)
    }

    @Test("Slot cell is walkable")
    func slotIsWalkable() {
        #expect(CellContent.slot(Entity()).isWalkable)
    }

    @Test("Wall is not walkable")
    func wallNotWalkable() {
        #expect(!CellContent.wall(Entity()).isWalkable)
    }

    @Test("Box is not walkable")
    func boxNotWalkable() {
        #expect(!CellContent.box(Entity()).isWalkable)
    }

    @Test("BoxOnSlot is not walkable")
    func boxOnSlotNotWalkable() {
        #expect(!CellContent.boxOnSlot(Entity()).isWalkable)
    }

    @Test("Player is not walkable")
    func playerNotWalkable() {
        #expect(!CellContent.player(Entity()).isWalkable)
    }

    // MARK: - isBox

    @Test("Box returns isBox true")
    func boxIsBox() {
        #expect(CellContent.box(Entity()).isBox)
    }

    @Test("BoxOnSlot returns isBox true")
    func boxOnSlotIsBox() {
        #expect(CellContent.boxOnSlot(Entity()).isBox)
    }

    @Test("Empty does not report as box")
    func emptyNotBox() {
        #expect(!CellContent.empty.isBox)
    }

    @Test("Wall does not report as box")
    func wallNotBox() {
        #expect(!CellContent.wall(Entity()).isBox)
    }

    // MARK: - isWall

    @Test("Wall returns isWall true")
    func wallIsWall() {
        #expect(CellContent.wall(Entity()).isWall)
    }

    @Test("Box does not report as wall")
    func boxNotWall() {
        #expect(!CellContent.box(Entity()).isWall)
    }

    // MARK: - isBoxOnSlot

    @Test("BoxOnSlot returns isBoxOnSlot true")
    func boxOnSlotIsBoxOnSlot() {
        #expect(CellContent.boxOnSlot(Entity()).isBoxOnSlot)
    }

    @Test("Regular box does not report as boxOnSlot")
    func boxNotBoxOnSlot() {
        #expect(!CellContent.box(Entity()).isBoxOnSlot)
    }

    // MARK: - boxEntity

    @Test("boxEntity extracts entity from box")
    func boxEntityFromBox() {
        let entity = Entity()
        let cell = CellContent.box(entity)
        #expect(cell.boxEntity === entity)
    }

    @Test("boxEntity extracts entity from boxOnSlot")
    func boxEntityFromBoxOnSlot() {
        let entity = Entity()
        let cell = CellContent.boxOnSlot(entity)
        #expect(cell.boxEntity === entity)
    }

    @Test("boxEntity returns nil for empty")
    func boxEntityNilForEmpty() {
        #expect(CellContent.empty.boxEntity == nil)
    }

    @Test("boxEntity returns nil for wall")
    func boxEntityNilForWall() {
        #expect(CellContent.wall(Entity()).boxEntity == nil)
    }

    // MARK: - entity

    @Test("Empty cell has nil entity")
    func emptyEntityNil() {
        #expect(CellContent.empty.entity == nil)
    }

    @Test("Non-empty cells have associated entity")
    func nonEmptyEntityNotNil() {
        let entity = Entity()
        #expect(CellContent.wall(entity).entity === entity)
        #expect(CellContent.box(entity).entity === entity)
        #expect(CellContent.boxOnSlot(entity).entity === entity)
        #expect(CellContent.player(entity).entity === entity)
        #expect(CellContent.slot(entity).entity === entity)
    }
}
