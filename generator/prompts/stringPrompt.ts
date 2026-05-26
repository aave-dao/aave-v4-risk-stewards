import {flagAsRequired} from '../common';
import {advancedInput} from './advancedInput';
import {GenericPrompt} from './types';

export async function stringPrompt<T extends boolean>({
  message,
  defaultValue,
  required,
}: GenericPrompt<T>) {
  return advancedInput({
    message: flagAsRequired(message, required),
    default: defaultValue,
    validate: (v) => (required ? v.trim().length != 0 : true),
  });
}
