/**
 * Gênero informado no cadastro. `null` significa "não informado" — o valor
 * nunca é inferido a partir do nome da pessoa.
 */
export type Gender = 'MASCULINO' | 'FEMININO';

export const GENDERS: readonly Gender[] = ['MASCULINO', 'FEMININO'];
