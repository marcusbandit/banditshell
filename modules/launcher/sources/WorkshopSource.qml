import QtQuick
import qs.services

QtObject {
    id: root

    required property var search

    function openWorkshop(name: string): void {
        const screen = root.search.screenName;
        root.search.leave(() => {
            LayoutDraft.open(name, "stage");
            Settings.openAt(screen, "windows", "");
        });
    }

    readonly property var commands: [
        {
            id: "layout-workshop",
            icon: "draw",
            label: "Layout workshop",
            words: "layout workshop draw tiling custom lua windows arrange",
            detail: WorkshopLayouts.layouts.length ? WorkshopLayouts.layouts.map(model => model.name).join(" · ") : "",
            run: () => root.openWorkshop("")
        }
    ].concat(WorkshopLayouts.layouts.map(model => ({
                id: `layout-workshop:${model.name}`,
                icon: "edit",
                label: `Edit ${model.name} layout`,
                words: `layout workshop edit ${model.name}`,
                run: () => root.openWorkshop(model.name)
            })))
}
