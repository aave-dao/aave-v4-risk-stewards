import {advancedInput} from './advancedInput';
import {GenericPrompt} from './types';

export type PercentInputValues = string;

function isNumber(value: string) {
  return !isNaN(value as unknown as number);
}

export function transformNumberToPercent(value: string) {
  if (value && isNumber(value)) {
    return (
      new Intl.NumberFormat('en-us', {maximumFractionDigits: 2}).format(
        value as unknown as number,
      ) + ' %'
    );
  }
  return value;
}

export async function percentPrompt<T extends boolean>({
  message,
  required,
}: GenericPrompt<T>): Promise<string> {
  return await advancedInput({
    message,
    transformer: transformNumberToPercent,
    validate: (v) => {
      if (required && v.length == 0) return false;
      return isNumber(v);
    },
    pattern: /^[0-9]*\.?[0-9]*$/,
    patternError: 'Only decimal numbers are allowed (e.g. 1.1)',
  });
}

/// Translate a percent (e.g. "1.05") to a BPS Solidity literal (e.g. "1_05"). Empty input emits
/// the requested KEEP_CURRENT sentinel — uint256 sentinel by default.
export function translateJsPercentToSol(
  value?: string,
  sentinel:
    | 'KEEP_CURRENT'
    | 'KEEP_CURRENT_UINT16'
    | 'KEEP_CURRENT_UINT32'
    | 'KEEP_CURRENT_UINT64' = 'KEEP_CURRENT',
) {
  if (!value) return `EngineFlags.${sentinel}`;
  const formattedValue = new Intl.NumberFormat('en-us', {
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  }).format(value as unknown as number);
  return (
    Number(value) >= 1 ? formattedValue : formattedValue.replace(/^0\.0*(?=[0-9])/, '')
  ).replace(/[\.,]/g, '_');
}
