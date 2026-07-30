export interface Church {
  readonly id: string;
  readonly name: string;
  readonly slug: string;
  readonly address: string | null;
  readonly site: string | null;
  readonly instagram: string | null;
  readonly youtube: string | null;
  readonly tiktok: string | null;
  readonly logoKey: string | null;
  readonly menuColor: string;
  readonly isActive: boolean;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface UpdateChurchData {
  readonly name?: string | undefined;
  readonly address?: string | null | undefined;
  readonly site?: string | null | undefined;
  readonly instagram?: string | null | undefined;
  readonly youtube?: string | null | undefined;
  readonly tiktok?: string | null | undefined;
  readonly menuColor?: string | undefined;
}

export interface CreateChurchData {
  readonly name: string;
  readonly slug: string;
  readonly address?: string | null | undefined;
  readonly menuColor?: string | undefined;
}
