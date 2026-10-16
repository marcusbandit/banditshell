pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../modules/workshop/layout-model.js" as LayoutModel

Singleton {
    id: root

    property bool editing: false
    property string original: ""
    property var model: LayoutModel.stage()
    property int arrangement: 0
    property string selected: "main"
    property int count: 3
    property int shapeIndex: 0
    property string problem: ""

    readonly property var shapes: {
        const out = [];
        const known = Hyprland.monitors.values.map(monitor => monitor.name);
        for (const screen of Quickshell.screens)
            if (known.indexOf(screen.name) >= 0 && !out.some(s => s.width === screen.width && s.height === screen.height))
                out.push({
                    width: screen.width,
                    height: screen.height
                });
        for (const shape of LayoutModel.SHAPES)
            if (out.length < 3 && !out.some(s => s.width === shape.width && s.height === shape.height))
                out.push(shape);
        return out.slice(0, 3);
    }
    readonly property var shape: root.shapes[Math.min(root.shapeIndex, root.shapes.length - 1)]
    readonly property var area: ({
            x: 0,
            y: 0,
            w: root.shape.width,
            h: root.shape.height
        })

    readonly property int last: root.model.arrangements.length - 1
    readonly property var current: root.model.arrangements[Math.max(0, Math.min(root.arrangement, root.model.arrangements.length - 1))]
    readonly property var running: LayoutModel.arrange(root.model, root.area, root.count, {})
    readonly property var found: LayoutModel.findRegion(root.current.root, root.selected)
    readonly property var region: root.found ? root.found.region : root.current.root
    readonly property var parentRegion: root.found ? root.found.parent : null
    readonly property bool leaf: root.region.kind !== "split"
    readonly property int siblingIndex: root.parentRegion ? root.parentRegion.children.findIndex(c => c.id === root.region.id) : -1
    readonly property var holders: LayoutModel.holderIds(root.current)
    readonly property var warnings: LayoutModel.problems(root.model)
    readonly property string nameProblem: WorkshopLayouts.problemWith(root.model, root.original)

    function arrangementName(index: int): string {
        return index === 0 ? "main" : `fallback ${index}`;
    }

    function open(name: string, starter: string): void {
        const saved = name ? WorkshopLayouts.find(name) : null;
        const make = LayoutModel.STARTERS.find(s => s.id === starter) ?? LayoutModel.STARTERS[0];
        root.original = saved ? name : "";
        root.arrangement = 0;
        root.model = saved ? LayoutModel.normalise(saved) : make.make(root.freeName(make.id === "stage" ? "stage-drawn" : make.id));
        root.selected = LayoutModel.holderIds(root.model.arrangements[0])[0] ?? root.model.arrangements[0].root.id;
        root.problem = "";
        root.editing = true;
    }

    function close(): void {
        root.editing = false;
    }

    function freeName(stem: string): string {
        const used = WorkshopLayouts.layouts.map(m => m.name).concat(WorkshopLayouts.taken);
        if (used.indexOf(stem) < 0)
            return stem;
        let n = 2;
        while (used.indexOf(`${stem}-${n}`) >= 0)
            n += 1;
        return `${stem}-${n}`;
    }

    function pickArrangement(index: int): void {
        root.arrangement = index;
        root.selected = root.current.root.id;
    }

    function change(next: var): void {
        root.model = next;
        root.problem = "";
        if (!LayoutModel.findRegion(root.current.root, root.selected))
            root.selected = root.current.root.id;
    }

    function setRegion(fields: var): void {
        root.change(LayoutModel.setRegion(root.model, root.arrangement, root.region.id, fields));
    }

    function split(axis: string): void {
        const made = LayoutModel.split(root.model, root.arrangement, root.region.id, axis);
        root.change(made.model);
        if (made.made)
            root.selected = made.made;
    }

    function removeRegion(): void {
        if (!root.parentRegion)
            return;
        const parentId = root.parentRegion.id;
        const other = root.parentRegion.children.find(c => c.id !== root.region.id);
        const many = root.parentRegion.children.length > 2;
        root.change(LayoutModel.remove(root.model, root.arrangement, root.region.id));
        root.selected = many ? parentId : other.id;
    }

    function addFallback(): void {
        root.change(LayoutModel.addFallback(root.model, root.arrangement));
        root.pickArrangement(root.last);
    }

    function removeArrangement(): void {
        const at = root.arrangement;
        root.arrangement = Math.max(0, at - 1);
        root.change(LayoutModel.removeArrangement(root.model, at));
        root.selected = root.current.root.id;
    }

    function orderAdd(list: string, id: string): void {
        const first = root.current.order.first.slice();
        const repeat = root.current.order.repeat.slice();
        (list === "first" ? first : repeat).push(id);
        root.change(LayoutModel.setOrder(root.model, root.arrangement, first, repeat));
    }

    function orderDrop(list: string, at: int): void {
        const first = root.current.order.first.slice();
        const repeat = root.current.order.repeat.slice();
        (list === "first" ? first : repeat).splice(at, 1);
        root.change(LayoutModel.setOrder(root.model, root.arrangement, first, repeat));
    }

    function save(andUse: bool): void {
        const problem = andUse ? WorkshopLayouts.use(root.model, root.original) : WorkshopLayouts.save(root.model, root.original, null);
        root.problem = problem;
        if (!problem)
            root.original = root.model.name;
    }
}
