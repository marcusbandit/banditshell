.pragma library

function windowsToBring(text, pid, special, workspace, brought) {
    let clients = [];
    try {
        clients = JSON.parse(text);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(clients) || !(pid > 0))
        return [];
    return clients.filter(client => client && client.pid === pid && client.mapped !== false && client.address && !brought.includes(client.address)).map(client => ({
                address: client.address,
                move: special ? client.workspace?.name !== special : (client.workspace?.id ?? 0) !== workspace
            }));
}
