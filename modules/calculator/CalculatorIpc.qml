import qs.services
import qs.modules

PanelIpc {
    target: "calculator"

    function app(): string {
        const win = Shell.showing(w => w.calculator.open);
        if (!win)
            return "no shell window";
        if (win.calculator.open && win.calculator.item.full)
            return close();
        win.calculator.build().app();
        return "open";
    }

    function panel(): string {
        const win = Shell.showing(w => w.calculator.open);
        if (!win)
            return "no shell window";
        if (win.calculator.open && !win.calculator.item.full)
            return close();
        win.calculator.build().panel();
        return "open";
    }

    function status(): string {
        const win = Shell.showing(w => w.calculator.open);
        return `open=${win?.calculator.open ?? false} shape=${win?.calculator.item?.full ? "app" : "panel"}`;
    }

    function answer(expression: string): string {
        const result = Calculator.evaluate(expression);
        return result ? result.text : `not an expression: ${expression}`;
    }
}
