
class GlossaryData {
  static const Map<String, GlossaryTerm> terms = {
    'volume_landmarks': GlossaryTerm(
      title: 'Volume Landmarks',
      definition: 'Pontos de referência para gerenciar o volume de treino (séries/semana) e otimizar hipertrofia.',
      details: '''
**Manutenção (MV):** < 10 séries. Volume mínimo para manter a massa muscular atual.
**Mínimo Efetivo (MEV):** 6-12 séries. Menor dose necessária para iniciar o crescimento.
**Máximo Adaptativo (MAV):** 12-22 séries. Faixa onde ocorrem os melhores ganhos ("Sweet Spot").
**Máximo Recuperável (MRV):** 20-30+ séries. Limite superior onde a recuperação se torna impossível.
''',
      source: 'Mike Israetel / RP Strength',
    ),
    'rpe': GlossaryTerm(
      title: 'RPE & RIR',
      definition: 'Escalas para medir a intensidade do esforço e proximidade da falha (Hard Sets).',
      details: '''
**RPE (Percepção Subjetiva de Esforço):**
• **10:** Falha total (0 repetições sobrando).
• **9:** 1 repetição no tanque (1 RIR).
• **8:** 2 repetições no tanque (2 RIR).
• **7:** 3 repetições no tanque (3 RIR).

Recomenda-se manter a maioria das séries entre **RPE 7-9** para hipertrofia sustentável sem fadiga excessiva.
''',
    ),
    'mechanical_tension': GlossaryTerm(
      title: 'Tensão Mecânica',
      definition: 'A força exercida nas fibras musculares sob carga.',
      details: '''
Considerada o principal motor da hipertrofia. É maximizada movendo cargas desafiadoras em uma amplitude de movimento completa (ROM), especialmente na posição alongada, e com controle de tempo (2-8s por repetição).
Diferente do treino de força (mover peso eficientemente), a hipertrofia busca o "caminho de maior resistência".
''',
    ),
    'hard_sets': GlossaryTerm(
      title: 'Hard Sets',
      definition: 'Séries que contam efetivamente para o volume.',
      details: '''
Uma "Hard Set" é qualquer série realizada com alta qualidade técnica e levada próxima à falha momentânea (geralmente **RPE ≥ 7**).
Séries leves demais (aquecimento ou "junk volume") não contam para o estímulo de hipertrofia.
''',
    ),
    'recovery': GlossaryTerm(
      title: 'Recuperação & Deload',
      definition: 'Estratégias para dissipar fadiga e prevenir Overtraining.',
      details: '''
O crescimento muscular ocorre no descanso, não no treino.
**Pilares:**
• Sono (7-9h)
• Nutrição (Proteína 1.6-2.2g/kg)
• Gerenciamento de Stress
• **Deload:** Redução estratégica (40-60% do volume) a cada 4-8 semanas para permitir supercompensação e evitar lesões.
''',
    ),
  };
}

class GlossaryTerm {
  final String title;
  final String definition;
  final String details;
  final String? source;

  const GlossaryTerm({
    required this.title,
    required this.definition,
    required this.details,
    this.source,
  });
}
