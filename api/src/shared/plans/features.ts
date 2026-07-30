/**
 * Catálogo de features (recursos) que podem ser liberados por plano.
 * A lista efetiva de cada igreja vem de `Plan.features` (no banco); estas são as
 * chaves canônicas usadas pelo gating na API e no app.
 */
export const FEATURES = {
  SPIRITUAL_HISTORY: 'spiritual_history',
  COORDENACAO: 'coordenacao',
  MATERIALS: 'materials',
  MAP_GEOLOCATION: 'map_geolocation',
  ADVANCED_DASHBOARD: 'advanced_dashboard',
  WHATSAPP: 'whatsapp',
} as const;

export type FeatureKey = (typeof FEATURES)[keyof typeof FEATURES];

export const ALL_FEATURES: FeatureKey[] = Object.values(FEATURES);

export interface FeatureCatalogItem {
  readonly key: FeatureKey;
  readonly label: string;
  readonly description: string;
}

/**
 * Catálogo com rótulos amigáveis — consumido pelo editor de planos (super-admin)
 * e pela landing. É a fonte de verdade das features selecionáveis num plano.
 */
export const FEATURE_CATALOG: FeatureCatalogItem[] = [
  {
    key: FEATURES.SPIRITUAL_HISTORY,
    label: 'Histórico espiritual',
    description: 'Registro da jornada espiritual dos visitantes (batismo, treinamentos...).',
  },
  {
    key: FEATURES.COORDENACAO,
    label: 'Coordenações e hierarquia',
    description: 'Estrutura de coordenações, supervisores e líderes.',
  },
  {
    key: FEATURES.MATERIALS,
    label: 'Materiais das células',
    description: 'Upload e compartilhamento de materiais (PDF, vídeo...).',
  },
  {
    key: FEATURES.MAP_GEOLOCATION,
    label: 'Mapa e geolocalização',
    description: 'Busca de células por proximidade e mapa.',
  },
  {
    key: FEATURES.ADVANCED_DASHBOARD,
    label: 'Dashboard avançado',
    description: 'Relatórios e indicadores avançados.',
  },
  {
    key: FEATURES.WHATSAPP,
    label: 'WhatsApp',
    description: 'Envio de mensagens e campanhas via WhatsApp.',
  },
];

/** Recursos sempre disponíveis (não dependem de plano). */
export const CORE_FEATURES = [
  'cells',
  'members',
  'visitors',
  'attendance',
  'dashboard',
] as const;
