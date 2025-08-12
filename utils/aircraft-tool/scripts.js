
function getPilotCount() {
    let maxIndex = 0;
    for (const entry of document.querySelectorAll('#pilotsList .input-pilot')) {
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

document.addEventListener("DOMContentLoaded", () => {
    document.getElementById("addPilotBtn")
        .addEventListener("click", () => addPilot());
    document.getElementById("clearPilotsBtn")
        .addEventListener("click", () => deletePilots());

    for (let i = 0; i < 3; i++) {
        addPilot();
    }

    // TODO generalize for all tooltips
    const tooltipButton = document.getElementById("googleCalendarIdInfoBtn");
    const tooltipElement = document.getElementById("googleCalendarIdInfoTooltip");
    const popperInstance = Popper.createPopper(tooltipButton, tooltipElement, {
        placement: 'right',
        modifiers: [
            {
                name: 'offset',
                options: {
                    offset: [0, 8],
                },
            },
        ],
    });
    tooltipButton.addEventListener("click", () => {
        if (tooltipElement.hasAttribute("data-show")) {
            tooltipElement.removeAttribute('data-show');
        }
        else {
            tooltipElement.setAttribute('data-show', '');
            popperInstance.update();
        }
    });

});
