for (const button of document.querySelectorAll("[data-copy]")) {
    let reset = 0;
    button.addEventListener("click", async () => {
        const code = button.previousElementSibling;
        try {
            await navigator.clipboard.writeText(code.textContent);
            button.textContent = "Copied";
        } catch {
            getSelection().selectAllChildren(code);
            button.textContent = "Selected";
        }
        clearTimeout(reset);
        reset = setTimeout(() => (button.textContent = "Copy"), 1600);
    });
}

for (const machine of document.querySelectorAll("[data-machine]")) {
    const deck = machine.querySelector(".deck");
    const buttons = [...deck.querySelectorAll("[data-state]")];
    const layers = [...machine.querySelectorAll("[data-layer]")];
    let current = buttons.find((button) => button.getAttribute("aria-checked") === "true")?.dataset.state ?? "rest";

    const show = (state) => {
        current = state;
        for (const button of buttons) {
            const on = button.dataset.state === state;
            button.setAttribute("aria-checked", String(on));
            button.tabIndex = on ? 0 : -1;
        }
        for (const layer of layers) {
            const on = layer.dataset.layer === state;
            layer.classList.toggle("on", on);
            layer.setAttribute("aria-hidden", String(!on));
        }
    };

    const step = {
        ArrowRight: 1,
        ArrowDown: 1,
        ArrowLeft: -1,
        ArrowUp: -1,
    };

    for (const button of buttons) {
        button.addEventListener("click", () => {
            const state = button.dataset.state;
            show(state === current && state !== "rest" ? "rest" : state);
        });
    }

    deck.addEventListener("keydown", (event) => {
        const at = buttons.indexOf(document.activeElement);
        let next = null;
        if (event.key in step) next = buttons[(at + step[event.key] + buttons.length) % buttons.length];
        else if (event.key === "Home") next = buttons[0];
        else if (event.key === "End") next = buttons.at(-1);
        else if (event.key === "Escape" && current !== "rest") next = buttons.find((button) => button.dataset.state === "rest");
        if (!next) return;
        event.preventDefault();
        show(next.dataset.state);
        next.focus();
    });

    deck.hidden = false;
}
