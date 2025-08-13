
function buildAircraftId() {
    return document.getElementById("callsign").value.trim().toLowerCase().replaceAll("-", "");
}

function createAircraftJson(adminMode) {
    return JSON.stringify({
        "admin": adminMode,
        "aircraft_id": buildAircraftId(),
        "callsign": document.getElementById("callsign").value.trim(),
        "backend_info": {
            "google_api_service_account": document.getElementById("googleApiServiceAccount").value,
            "google_api_key": document.getElementById("googleApiKey").value,
            "google_calendar_id": document.getElementById("googleCalendarId").value?.trim() || null,
            "flightlog_spreadsheet_id": document.getElementById("googleSpreadsheetId").value?.trim() || null,
            "flightlog_sheet_name": document.getElementById("flightlogSheetName").value?.trim() || null,
            "activities_spreadsheet_id": document.getElementById("googleSpreadsheetId").value?.trim() || null,
            "activities_sheet_name": document.getElementById("activitiesSheetName").value?.trim() || null,
            "metadata_spreadsheet_id": document.getElementById("googleSpreadsheetId").value?.trim() || null,
            "metadata_sheet_name": document.getElementById("metadataSheetName").value?.trim() || null,
        },
        "no_pilot_name": document.getElementById("pilotNameNone").value.trim(),
        "pilot_names": Array.from(document.querySelectorAll("#pilotsList input.pilot-name"))
            .filter(element => element.value.trim().length > 0)
            .map(element => element.value.trim()),
        "documents_archive": document.getElementById("documentsArchiveUrl").value?.trim() || null,
        "location": {
            "name": document.getElementById("hangarName").value.trim(),
            "latitude": document.getElementById("hangarLat").valueAsNumber,
            "longitude": document.getElementById("hangarLon").valueAsNumber,
            "timezone": document.getElementById("hangarTz").value.trim(),
            "weather_live": document.getElementById("weatherLiveUrl").value?.trim() || null,
            "weather_forecast": document.getElementById("weatherForecastUrl").value?.trim() || null,
        },
    }, null, 2);
}

function startProgress() {
    document.querySelectorAll("#generateActions button").forEach(button => button.disabled = true);
    document.getElementById('progressIndicator').classList.remove('visually-hidden');
}

function stopProgress() {
    document.querySelectorAll("#generateActions button").forEach(button => button.disabled = false);
    document.getElementById('progressIndicator').classList.add('visually-hidden');
}

async function generateAndDownloadZip(adminMode) {
    startProgress();

    try {
        const zip = new JSZip();

        zip.file("aircraft.json", createAircraftJson(adminMode));

        // pilot avatars
        const pilotNames = Array.from(document.querySelectorAll("#pilotsList input.pilot-name"))
            .filter(element => element.value.trim().length > 0)
            .map(element => element.value);
        const pilotAvatars = Array.from(document.querySelectorAll("#pilotsList img.pilot-avatar"))
            .map(element => element.src);
        for (const pilotIndex in pilotAvatars) {
            const avatarData = await fetch(pilotAvatars[pilotIndex]);
            const avatar = await avatarData.blob();
            const name = pilotNames[pilotIndex].toLowerCase();
            zip.file(`avatar-${name}.jpg`, avatar);
        }

        // aircraft photo
        const photoData = await fetch(document.getElementById("aircraftPhoto").src);
        const photo = await photoData.blob();
        zip.file("aircraft.jpg", photo);

        const zipBlob = await zip.generateAsync({
            type: 'blob',
            compression: 'DEFLATE',
            compressionOptions: { level: 6 }
        });

        const url = URL.createObjectURL(zipBlob);
        const a = document.createElement('a');
        a.href = url;

        a.download = `${buildAircraftId()}${adminMode ? "-admin" : ""}.zip`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

    }
    catch (error) {
        console.error("Error generating zip file", error);
        alert("Error generating zip file.");
    }
    finally {
        stopProgress();
    }
}

function openBlobStorage(dbName) {
    const request = indexedDB.open(dbName, 1);

    request.onupgradeneeded = e => {
        /** @type {IDBDatabase} */
        const db = e.target.result;
        if (!db.objectStoreNames.contains("files")) {
            db.createObjectStore("files");
        }
    };

    return request;
}

function deleteStore(dbName) {
    return new Promise((resolve, reject) => {
        const request = openBlobStorage(dbName);
        request.onsuccess = e => {
            /** @type {IDBDatabase} */
            const db = e.target.result;
            const tx = db.transaction("files", "readwrite");
            tx.oncomplete = () => resolve();
            tx.onerror = err => reject(err);

            const store = tx.objectStore("files");
            store.clear();
        }
        request.onerror = err => reject(err);
    });
}

function persistBlob(dbName, key, blobUrl) {
    return new Promise((resolve, reject) => {
        fetch(blobUrl)
            .catch(reject)
            .then(res => {
                return res.blob();
            })
            .then(blob => {
                const request = openBlobStorage(dbName);

                request.onsuccess = e => {
                    /** @type {IDBDatabase} */
                    const db = e.target.result;
                    const tx = db.transaction("files", "readwrite");
                    tx.oncomplete = () => resolve();
                    tx.onerror = err => reject(err);

                    const store = tx.objectStore("files");
                    store.put(blob, key);
                };

                request.onerror = err => reject(err);
            })
            .catch(reject);
    });
}

function restoreBlob(dbName, key) {
    return new Promise((resolve, reject) => {
        const request = openBlobStorage(dbName);

        request.onsuccess = e => {
            /** @type {IDBDatabase} */
            const db = e.target.result;
            const tx = db.transaction("files", "readonly");
            const store = tx.objectStore("files");

            const read = store.get(key);

            read.onsuccess = (e) => resolve(e.target.result);
            read.onerror = err => reject(err);
        };

        request.onerror = err => reject(err);
    });
}

function getPilotCount() {
    let maxIndex = 0;
    for (const entry of document.querySelectorAll('#pilotsList .pilot-entry')) {
        const entryIndex = parseInt(entry.id.replace("pilotEntry", ""));
        maxIndex = Math.max(maxIndex, entryIndex);
    }
    return maxIndex;
}

function updateAvatar(index, file) {
    const reader = new FileReader();
    reader.onload = () => document.getElementById(`pilotAvatar${index}`).src = reader.result
    reader.readAsDataURL(file);
    //document.getElementById(`pilotAvatar${index}`).src = URL.createObjectURL(file);
    persistPilots();
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
    input.addEventListener("change", () => persistPilots());

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
    persistPilots();
}

function deletePilots() {
    const container = document.getElementById("pilotsList");
    container.replaceChildren();
    persistPilots();
}

function persistPilots() {
    const pilotNames = Array.from(document.querySelectorAll("#pilotsList input.pilot-name"))
        .filter(element => element.value.trim().length > 0)
        .map(element => element.value);
    localStorage.setItem(`autosave-pilotNames`, pilotNames.join("|"));

    deleteStore("pilotAvatars").then(() => {
        const pilotAvatars = Array.from(document.querySelectorAll("#pilotsList img.pilot-avatar"))
            .map(element => element.src);
        for (const pilotIndex in pilotAvatars) {
            persistBlob("pilotAvatars", `pilotAvatar${parseInt(pilotIndex) + 1}`, pilotAvatars[pilotIndex])
        }
    });
}

function restorePilots() {
    const pilotNames = localStorage.getItem(`autosave-pilotNames`);
    if (pilotNames !== null && pilotNames.trim().length > 0) {
        pilotNames.split("|").forEach((pilotName, pilotIndex) => {
            // add pilot entry
            addPilot();
            // restore pilot name
            document.getElementById(`pilotName${pilotIndex + 1}`).value = pilotName;
            // restore avatar
            restoreBlob("pilotAvatars", `pilotAvatar${pilotIndex + 1}`).then(blob => {
                if (blob) {
                    const reader = new FileReader();
                    reader.onload = () => document.getElementById(`pilotAvatar${pilotIndex + 1}`).src = reader.result
                    reader.readAsDataURL(blob);
                    //document.getElementById(`pilotAvatar${pilotIndex + 1}`).src = URL.createObjectURL(blob);
                }
            });
        });
    }
    else {
        for (let i = 0; i < 3; i++) {
            addPilot();
        }
    }
}

function restoreAircraftPhoto() {
    restoreBlob("aircraft", "photo").then(blob => {
        if (blob) {
            const reader = new FileReader();
            reader.onload = () => {
                document.getElementById(`aircraftPhoto`).src = reader.result;
                displayAircraftPhoto();
            }
            reader.readAsDataURL(blob);
        }
    });
}

function updateAircraftPhoto(file) {
    const reader = new FileReader();
    reader.onload = () => {
        persistBlob("aircraft", "photo", reader.result);
        document.getElementById(`aircraftPhoto`).src = reader.result;
    }
    reader.readAsDataURL(file);

    displayAircraftPhoto();
}

function displayAircraftPhoto() {
    document.getElementById("aircraftPhoto").classList.remove('visually-hidden');
    document.getElementById("aircraftPhotoDropZoneHelp").classList.add('visually-hidden');
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
    // setup events
    document.getElementById("addPilotBtn")
        .addEventListener("click", () => addPilot());
    document.getElementById("clearPilotsBtn")
        .addEventListener("click", () => deletePilots());

    const photoDropZone = document.getElementById("aircraftPhotoDropZone");
    photoDropZone.addEventListener('click', () => document.getElementById("aircraftPhotoFile").click());
    photoDropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.target.classList.add('drag-over');
    });
    photoDropZone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        e.target.classList.remove('drag-over');
    });
    photoDropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        e.target.classList.remove('drag-over');
        updateAircraftPhoto(e.dataTransfer.files[0]);
    });

    const photoFile = document.getElementById("aircraftPhotoFile");
    photoFile.addEventListener('change', (e) => {
        updateAircraftPhoto(e.target.files[0]);
    });

    // tooltips
    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));

    // automatic form validation
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

    // form validation and submit
    document.getElementById('mainForm').addEventListener('submit', e => {
        // we handle the submit ourselves
        e.preventDefault();
        e.stopPropagation();

        e.target.classList.add('was-validated');

        if (!e.target.checkValidity()) {
            document.getElementById('mainFormInvalid').classList.remove('visually-hidden');
            document.getElementById('mainFormValid').classList.add('visually-hidden');
        }
        else {
            document.getElementById('mainFormInvalid').classList.add('visually-hidden');
            document.getElementById('mainFormValid').classList.remove('visually-hidden');

            generateAndDownloadZip(e.submitter.id === "generateAdminBtn");
        }
    }, false);

    // save/restore state to/from local storage
    // pilots state needs special handling because it's dynamic and has files (avatars)
    document.querySelectorAll("input, textarea").forEach(element => {
        if (element.type === "file") {
            return;
        }

        const saved = localStorage.getItem(`autosave-${element.id}`);
        if (saved !== null) {
            element.value = saved;
        }

        element.addEventListener("input", () => {
            localStorage.setItem(`autosave-${element.id}`, element.value);
        });
    });

    // restore or create pilot entries
    // we do this after setting the autosave event handlers because another method is used to persist pilots
    restorePilots();

    // restore aircraft photo
    restoreAircraftPhoto();
});
