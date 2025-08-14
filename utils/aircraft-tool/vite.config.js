import { resolve } from 'path'

export default {
    base: './',
    root: resolve(__dirname),
    resolve: {
        alias: {
            '~bootstrap': resolve(__dirname, 'node_modules/bootstrap'),
        }
    },
    server: {
        port: 5173,
        hot: true
    },
}
