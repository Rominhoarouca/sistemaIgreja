"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
const winston_1 = __importDefault(require("winston"));
const { combine, timestamp, colorize, printf, json, errors } = winston_1.default.format;
const isDev = process.env['NODE_ENV'] === 'development';
// Accepts any level supported by winston: error | warn | info | http | verbose | debug | silly
const level = (process.env['LOG_LEVEL'] ?? (isDev ? 'http' : 'warn')).toLowerCase();
const devFormat = combine(errors({ stack: true }), colorize({ all: true }), timestamp({ format: 'HH:mm:ss' }), printf(({ level, message, timestamp, stack, ...meta }) => {
    const extra = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    return `[${timestamp}] ${level}: ${stack ?? message}${extra}`;
}));
const prodFormat = combine(errors({ stack: true }), timestamp(), json());
exports.logger = winston_1.default.createLogger({
    level,
    format: isDev ? devFormat : prodFormat,
    transports: [new winston_1.default.transports.Console()],
});
