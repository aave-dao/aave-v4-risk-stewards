import {
  createPrompt,
  useState,
  useKeypress,
  usePrefix,
  isEnterKey,
  isBackspaceKey,
} from '@inquirer/core';
import chalk from 'chalk';

export type InputConfig = {
  message: string;
  default?: string;
  transformer?: (value: string, ctx: {isFinal: boolean}) => string;
  validate?: (value: string) => boolean | string | Promise<string | boolean>;
  pattern?: RegExp;
  patternError?: string;
};

/**
 * Modified input prompt that supports a pattern: any non-conforming keystroke is discarded and an
 * error is shown. Direct port from the v3 generator.
 */
export const advancedInput = createPrompt<string, InputConfig>((config, done) => {
  const {validate = () => true, pattern, patternError} = config;
  const [status, setStatus] = useState<string>('pending');
  const [defaultValue = '', setDefaultValue] = useState<string | undefined>(config.default);
  const [errorMsg, setError] = useState<string | undefined>(undefined);
  const [value, setValue] = useState<string>('');

  const isLoading = status === 'loading';
  const prefix = usePrefix({isLoading});

  useKeypress(async (key, rl) => {
    if (status !== 'pending') return;

    if (isEnterKey(key)) {
      const answer = value || defaultValue;
      setStatus('loading');
      const isValid = await validate(answer);
      if (isValid === true) {
        setValue(answer);
        setStatus('done');
        done(answer);
      } else {
        rl.write(value);
        setError((isValid as string) || 'You must provide a valid value');
        setStatus('pending');
      }
    } else if (isBackspaceKey(key) && !value) {
      setDefaultValue(undefined);
    } else if (key.name === 'tab' && !value) {
      setDefaultValue(undefined);
      rl.clearLine(0);
      rl.write(defaultValue);
      setValue(defaultValue);
    } else if (!pattern || pattern.test(rl.line)) {
      setValue(rl.line);
      setError(undefined);
    } else {
      const line = rl.line;
      rl.clearLine(0);
      rl.write(line.slice(0, -1));
      setError(patternError);
    }
  });

  const message = chalk.bold(config.message);
  let formattedValue = value;
  if (typeof config.transformer === 'function') {
    formattedValue = config.transformer(value, {isFinal: status === 'done'});
  }
  if (status === 'done') formattedValue = chalk.cyan(formattedValue);

  let defaultStr = '';
  if (defaultValue && status !== 'done' && !value) defaultStr = chalk.dim(` (${defaultValue})`);

  const error = errorMsg ? chalk.red(`> ${errorMsg}`) : '';

  return [`${prefix} ${message}${defaultStr} ${formattedValue}`, error];
});
