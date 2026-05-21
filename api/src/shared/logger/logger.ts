import winston from 'winston';

const { combine, timestamp, colorize, printf, json, errors } = winston.format;

const isDev = process.env['NODE_ENV'] === 'development';

// Accepts any level supported by winston: error | warn | info | http | verbose | debug | silly
const level = (process.env['LOG_LEVEL'] ?? (isDev ? 'http' : 'warn')).toLowerCase();

const devFormat = combine(
  errors({ stack: true }),
  colorize({ all: true }),
  timestamp({ format: 'HH:mm:ss' }),
  printf(({ level, message, timestamp, stack, ...meta }) => {
    const extra = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    return `[${timestamp}] ${level}: ${stack ?? message}${extra}`;
  }),
);

const prodFormat = combine(
  errors({ stack: true }),
  timestamp(),
  json(),
);

export const logger = winston.createLogger({
  level,
  format: isDev ? devFormat : prodFormat,
  transports: [new winston.transports.Console()],
});
