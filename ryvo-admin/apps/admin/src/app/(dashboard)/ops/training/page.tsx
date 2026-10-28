'use client';

import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { apiFetch, apiMutate } from '@/lib/api';
import { toast } from 'sonner';

interface Option {
  label: string;
  isCorrect: boolean;
}
interface Question {
  prompt: string;
  options: Option[];
}
interface Block {
  type: 'text' | 'image' | 'video';
  body: string;
}
interface Program {
  id: string;
  title: string;
  passPercent: number;
  serviceCategoryId?: string | null;
  isActive: boolean;
  blocks: Block[];
  questions: { prompt: string; options: Option[] }[];
  serviceCategory?: { name: string } | null;
}
interface Category {
  id: string;
  name: string;
}
interface Equipment {
  id: string;
  label: string;
  serviceCategoryId: string;
  sortOrder: number;
  isActive: boolean;
  serviceCategory?: { name: string };
}
interface Bundle {
  programs: Program[];
  categories: Category[];
  equipment: Equipment[];
}

export default function TrainingAdminPage() {
  const queryClient = useQueryClient();
  const bundle = useQuery({
    queryKey: ['admin-training'],
    queryFn: async () => (await apiFetch<Bundle>('/admin/training')).data,
  });
  const [selectedId, setSelectedId] = useState<string>('new');
  const [title, setTitle] = useState('New training');
  const [passPercent, setPassPercent] = useState('80');
  const [serviceCategoryId, setServiceCategoryId] = useState('');
  const [blocksText, setBlocksText] = useState('text|Write the guidance here');
  const [questionsText, setQuestionsText] = useState('Question?\n*Correct answer\nWrong answer');
  const [equipmentLabel, setEquipmentLabel] = useState('');
  const [equipmentCategory, setEquipmentCategory] = useState('');

  const programs = bundle.data?.programs ?? [];
  const categories = bundle.data?.categories ?? [];

  const loadProgram = (program: Program) => {
    setSelectedId(program.id);
    setTitle(program.title);
    setPassPercent(String(program.passPercent));
    setServiceCategoryId(program.serviceCategoryId ?? '');
    setBlocksText(program.blocks.map((block) => `${block.type}|${block.body}`).join('\n'));
    setQuestionsText(
      program.questions
        .map((question) => [question.prompt, ...question.options.map((option) => `${option.isCorrect ? '*' : ''}${option.label}`)].join('\n'))
        .join('\n\n'),
    );
  };

  const parsed = useMemo(() => {
    const blocks: Block[] = blocksText
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => {
        const [type, ...rest] = line.split('|');
        const kind = type === 'image' || type === 'video' ? type : 'text';
        return { type: kind, body: rest.join('|') || line };
      });
    const questions: Question[] = questionsText
      .split(/\n\s*\n/)
      .map((chunk) => chunk.split('\n').map((line) => line.trim()).filter(Boolean))
      .filter((lines) => lines.length > 1)
      .map((lines) => ({
        prompt: lines[0],
        options: lines.slice(1).map((line) => ({
          isCorrect: line.startsWith('*'),
          label: line.replace(/^\*/, ''),
        })),
      }));
    return { blocks, questions };
  }, [blocksText, questionsText]);

  const save = useMutation({
    mutationFn: () =>
      apiMutate('/admin/training', 'POST', {
        id: selectedId === 'new' ? undefined : selectedId,
        title,
        passPercent: Number(passPercent) || 80,
        serviceCategoryId: serviceCategoryId || null,
        isActive: true,
        blocks: parsed.blocks,
        questions: parsed.questions,
      }),
    onSuccess: () => {
      toast.success('Training saved');
      queryClient.invalidateQueries({ queryKey: ['admin-training'] });
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const saveEquipment = useMutation({
    mutationFn: () =>
      apiMutate('/admin/equipment', 'POST', {
        serviceCategoryId: equipmentCategory,
        label: equipmentLabel,
        isActive: true,
      }),
    onSuccess: () => {
      toast.success('Equipment label saved');
      setEquipmentLabel('');
      queryClient.invalidateQueries({ queryKey: ['admin-training'] });
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <>
      <Header title="Training" description="Onboarding and per job-type modules, tests, and equipment labels." />
      <PageContent>
        <div className="grid gap-6 lg:grid-cols-[240px_1fr]">
          <Card>
            <CardContent className="space-y-2 p-3">
              <Button variant="outline" className="w-full" onClick={() => setSelectedId('new')}>
                New program
              </Button>
              {programs.map((program) => (
                <button
                  key={program.id}
                  className="w-full rounded-md px-2 py-2 text-left text-sm hover:bg-surface"
                  onClick={() => loadProgram(program)}
                >
                  {program.title}
                  <span className="block text-xs text-secondary">{program.serviceCategory?.name || 'Onboarding'}</span>
                </button>
              ))}
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Program</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" />
              <div className="grid grid-cols-2 gap-2">
                <Input value={passPercent} onChange={(e) => setPassPercent(e.target.value)} placeholder="Pass percent" />
                <select
                  className="rounded-md border border-border bg-surface px-3 py-2 text-sm"
                  value={serviceCategoryId}
                  onChange={(e) => setServiceCategoryId(e.target.value)}
                >
                  <option value="">Onboarding (no job type)</option>
                  {categories.map((category) => (
                    <option key={category.id} value={category.id}>
                      {category.name}
                    </option>
                  ))}
                </select>
              </div>
              <p className="text-xs text-secondary">Blocks: one per line, type|content. Types are text, image, or video. Image and video content is a URL.</p>
              <Textarea rows={6} value={blocksText} onChange={(e) => setBlocksText(e.target.value)} />
              <p className="text-xs text-secondary">Questions: blank line between questions. First line is the prompt. Prefix the correct option with *.</p>
              <Textarea rows={8} value={questionsText} onChange={(e) => setQuestionsText(e.target.value)} />
              <Button disabled={save.isPending} onClick={() => save.mutate()}>
                Save training
              </Button>
            </CardContent>
          </Card>
        </div>
        <Card className="mt-6">
          <CardHeader>
            <CardTitle className="text-base">Equipment labels</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {(bundle.data?.equipment ?? []).map((item) => (
              <p key={item.id} className="text-sm">
                {item.serviceCategory?.name}: {item.label}
              </p>
            ))}
            <div className="grid gap-2 md:grid-cols-[1fr_1fr_auto]">
              <select
                className="rounded-md border border-border bg-surface px-3 py-2 text-sm"
                value={equipmentCategory}
                onChange={(e) => setEquipmentCategory(e.target.value)}
              >
                <option value="">Job type</option>
                {categories.map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.name}
                  </option>
                ))}
              </select>
              <Input value={equipmentLabel} onChange={(e) => setEquipmentLabel(e.target.value)} placeholder="Label shown to the driver" />
              <Button disabled={!equipmentCategory || !equipmentLabel || saveEquipment.isPending} onClick={() => saveEquipment.mutate()}>
                Add
              </Button>
            </div>
          </CardContent>
        </Card>
      </PageContent>
    </>
  );
}
