export type MaterialFileType = 'pdf' | 'docx' | 'ppt' | 'video' | 'outro';

export interface Material {
  readonly id: string;
  readonly cellId: string;
  readonly title: string;
  readonly description: string | null;
  readonly url: string;
  readonly fileType: MaterialFileType;
  readonly sizeBytes: number;
  readonly uploadedById: string;
  readonly uploadedAt: Date;
}

export interface CreateMaterialData {
  readonly cellId: string;
  readonly title: string;
  readonly description?: string;
  readonly url: string;
  readonly fileType: MaterialFileType;
  readonly sizeBytes: number;
  readonly uploadedById: string;
}
