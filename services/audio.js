function uniqueLabels(entries) {
    const labels = {};
    const groups = {};
    for (const entry of entries.slice().sort((a, b) => a.key < b.key ? -1 : a.key > b.key ? 1 : 0)) {
        labels[entry.key] = entry.label;
        (groups[entry.label] = groups[entry.label] || []).push(entry);
    }

    for (const label of Object.keys(groups)) {
        const group = groups[label];
        if (group.length < 2)
            continue;

        for (const entry of group) {
            if (entry.card && entry.card !== entry.label)
                labels[entry.key] = `${entry.label} · ${entry.card}`;
        }

        const twins = {};
        for (const entry of group)
            (twins[labels[entry.key]] = twins[labels[entry.key]] || []).push(entry);

        for (const name of Object.keys(twins)) {
            if (twins[name].length < 2)
                continue;
            twins[name].forEach((entry, i) => {
                labels[entry.key] = `${name} ${i + 1}`;
            });
        }
    }
    return labels;
}
