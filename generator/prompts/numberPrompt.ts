import {advancedInput} from './advancedInput';
import {GenericPrompt} from './types';

export type NumberInputValues = string;

function isNumber(value: string) {
  return !isNaN(value as unknown as number);
}

export function transformNumberToHumanReadable(value: string) {
  if (value && isNumber(value)) {
    return new Intl.NumberFormat('en-us').format(BigInt(value));
  }
  return value;
}

export async function numberPrompt(
  {message, required}: GenericPrompt,
  opts?: {skipTransform?: boolean}
) {
  return await advancedInput({
    message,
    transformer: opts?.skipTransform ? undefined : transformNumberToHumanReadable,
    validate: (v) => {
      if (required && v.length == 0) return false;
      return isNumber(v);
    },
    pattern: /^[0-9]*$/,
    patternError: 'Only full numbers are allowed',
  });
}

/// Translate a JS string value into a Solidity literal. Empty value → KEEP_CURRENT sentinel
/// in the caller's chosen width — the default here is the uint256 sentinel; callers handling
/// narrower fields (irData uint16/uint32) should call `translateJsNumberToSolWidth` instead.
export function translateJsNumberToSol(value?: string) {
  if (!value) return `EngineFlags.KEEP_CURRENT`;
  return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, '_');
}

export function translateJsNumberToSolWidth(
  value: string | undefined,
  sentinel: 'KEEP_CURRENT' | 'KEEP_CURRENT_UINT16' | 'KEEP_CURRENT_UINT32' | 'KEEP_CURRENT_UINT64'
) {
  if (!value) return `EngineFlags.${sentinel}`;
  return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, '_');
}
