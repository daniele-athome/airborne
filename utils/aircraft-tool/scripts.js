
function getPilotCount() {
    let maxIndex = 0;
    for (const entry of document.querySelectorAll('#pilotsList .pilot-entry')) {
        const entryIndex = parseInt(entry.id.replace("pilotEntry", ""));
        maxIndex = Math.max(maxIndex, entryIndex);
    }
    return maxIndex;
}

function updateAvatar(index, file) {
    document.getElementById("pilotAvatar" + index).src = URL.createObjectURL(file);
}

function addPilot() {
    const rowIndex = getPilotCount() + 1;
    const template = document.getElementById("pilotNameForm");
    const container = document.getElementById("pilotsList");

    const templateClone = template.content.cloneNode(true);

    const row = templateClone.querySelector('#pilotEntryX');
    row.id = "pilotEntry" + rowIndex;

    const input = row.querySelector("#pilotNameX");
    input.id = "pilotName" + rowIndex;

    const label = row.querySelector("label");
    label.setAttribute("for", input.id);
    label.textContent = label.textContent.replace("__X__", rowIndex);

    const removeBtn = row.querySelector("#removePilotX");
    removeBtn.id = "removePilot" + rowIndex;
    removeBtn.addEventListener("click", () => deletePilot(rowIndex));

    const pilotAvatarFile = row.querySelector('#pilotAvatarFileX');
    pilotAvatarFile.id = "pilotAvatarFile" + rowIndex;
    pilotAvatarFile.addEventListener("change", (e) => updateAvatar(rowIndex, e.target.files[0]));

    const pilotAvatar = row.querySelector('#pilotAvatarX');
    pilotAvatar.id = "pilotAvatar" + rowIndex;
    pilotAvatar.addEventListener("click", () =>
        document.getElementById("pilotAvatarFile" + rowIndex).click());

    container.appendChild(templateClone);
}

function deletePilot(index) {
    document.getElementById("pilotEntry" + index).remove();
}

function deletePilots() {
    const container = document.getElementById("pilotsList");
    container.replaceChildren();
}

function checkValidity(element) {
    if (element.checkValidity()) {
        element.classList.add('is-valid');
        element.classList.remove('is-invalid');
    } else {
        element.classList.add('is-invalid');
        element.classList.remove('is-valid');
    }
}

document.addEventListener("DOMContentLoaded", () => {
    document.getElementById("addPilotBtn")
        .addEventListener("click", () => addPilot());
    document.getElementById("clearPilotsBtn")
        .addEventListener("click", () => deletePilots());

    for (let i = 0; i < 3; i++) {
        addPilot();
    }

    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));

    document.querySelectorAll('input, textarea').forEach(element => {
        if (element.type === "file") {
            return;
        }

        element.addEventListener('change', function () {
            checkValidity(element);
        });
        element.addEventListener('blur', function () {
            checkValidity(element);
        });
    });
});
