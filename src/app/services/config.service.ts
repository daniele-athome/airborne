import { Injectable } from '@angular/core';
import { Storage } from '@capacitor/storage';

@Injectable()
export class ConfigService {

    constructor() {
    }

    public async getLastPilotName(): Promise<string> {
        const ret = await Storage.get({key: 'lastPilotName'});
        return ret ? ret.value : null;
    }

    public async setLastPilotName(name: string) {
        await Storage.set({key: 'lastPilotName', value: name});
    }

}
