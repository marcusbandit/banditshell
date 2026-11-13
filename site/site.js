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
    let current = buttons.find((button) => button.getAttribute("aria-pressed") === "true")?.dataset.state ?? "rest";

    const show = (state) => {
        current = state;
        for (const button of buttons) button.setAttribute("aria-pressed", String(button.dataset.state === state));
        for (const layer of layers) {
            const on = layer.dataset.layer === state;
            layer.classList.toggle("on", on);
            layer.setAttribute("aria-hidden", String(!on));
        }
    };

    for (const button of buttons) {
        button.addEventListener("click", () => {
            const state = button.dataset.state;
            show(state === current && state !== "rest" ? "rest" : state);
        });
    }

    deck.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && current !== "rest") {
            show("rest");
            event.preventDefault();
        }
    });

    deck.hidden = false;
}
