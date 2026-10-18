for (const button of document.querySelectorAll("[data-copy]")) {
    button.addEventListener("click", async () => {
        const text = button.previousElementSibling.textContent;
        try {
            await navigator.clipboard.writeText(text);
            button.textContent = "Copied";
        } catch {
            getSelection().selectAllChildren(button.previousElementSibling);
            button.textContent = "Selected";
        }
        setTimeout(() => (button.textContent = "Copy"), 1600);
    });
}

for (const tour of document.querySelectorAll("[data-tour]")) {
    const items = [...tour.querySelectorAll("article")];
    const pick = (chosen) => {
        for (const item of items) {
            item.classList.toggle("on", item === chosen);
            item.querySelector(".tour-pick").setAttribute("aria-pressed", String(item === chosen));
        }
    };
    for (const item of items) {
        const button = item.querySelector(".tour-pick");
        button.addEventListener("click", () => pick(item));
        button.addEventListener("pointerenter", (e) => {
            if (e.pointerType === "mouse") pick(item);
        });
    }
}
