'use strict';
(() => {
  const player = document.getElementById('demo-player');
  if (!player) return;
  const byId = id => document.getElementById(id);
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const phrases = {
    title: ['用一个小问题，看懂双循环。', 'One small question. Two powerful loops.'],
    intro: ['让小模型更准确地识别手写数字。跟随一次教学演示，看调研、实验、反思与写作如何接成完整流程。', 'Help a small model recognize handwritten digits. Follow a teaching example from literature and ideas through experiments, reflection, and writing.'],
    label: ['教学示例 · 非真实实验数据', 'TEACHING DEMO · SIMULATED DATA'],
    play: ['播放', 'Play'], pause: ['暂停', 'Pause'], again: ['再看一遍', 'Play again'],
    next: ['下一步 →', 'Next step →'], restart: ['重播 ↺', 'Restart ↺'],
    routeResearch: ['调研与构思', 'Research & ideas'], routeSetup: ['选择实验路线', 'Choose a route'], routeSetup: ['选择实验路线', 'Choose a route'], routeLoops: ['双循环实验', 'Two-loop research'], routeWriting: ['写作与评审', 'Writing & review'],
    outerQuestion: ['下一步，该研究什么？', 'What should we investigate next?'],
    innerQuestion: ['这个想法，怎样做得更好？', 'How can this idea work better?'],
    nodeModify: ['改模型', 'Modify'], nodeRun: ['训练与测量', 'Train & measure'],
    nodeDecide: ['保留或回滚', 'Keep or revert'], fixedEval: ['固定评估', 'Fixed evaluation'],
    loopWaiting: ['先明确课题，再开始实验', 'Frame the question before experimenting'],
    loopBaseline: ['基线已记录，评估保持不变', 'Baseline recorded. Evaluation stays fixed.'],
    loopKeep: ['保留改进，再尝试下一次修改', 'Keep the improvement. Try the next change.'],
    loopRevert: ['撤回退步，回到已保留的模型', 'Revert the regression to the retained model.'],
    loopReflect: ['暂停内循环，交给外循环反思', 'Step out of the inner loop to reflect.'],
    loopReframe: ['新假设、新计划，同一套评估', 'New hypothesis. New plan. Same evaluation.'],
    loopPending: ['出现改进信号，复测后再决定', 'Promising signal. Recheck before deciding.'],
    loopConfirmed: ['复测后保留，再整理实验记录', 'Keep the rechecked result and record it.'],
    loopConclude: ['整理已保留的结果与失败记录', 'Preserve retained results and failed trials.'],
    reflectWaiting: ['跳出单次实验，看清下一步。', 'Look beyond a single experiment.'],
    reflectWaitingDetail: ['综合实验记录、检查错误、修订假设，再回到内循环。', 'Synthesize trials, inspect errors, and revise the hypothesis before another inner loop.'],
    reflectError: ['DEEPEN：歪斜数字为什么仍容易认错？', 'DEEPEN: why do tilted digits still fail?'],
    reflectErrorDetail: ['整体分数提高了，但这类错误仍集中出现。下一轮从模型容量转向旋转鲁棒性。', 'The overall score improved, but one error pattern remains. Shift from model capacity to rotation robustness.'],
    reflectH2: ['新假设：训练增强能改善旋转鲁棒性。', 'New hypothesis: augmentation could improve robustness.'],
    reflectH2Detail: ['只改变训练时的输入变换，评估集保持不变，回到内循环检验。', 'Change training-time transforms only. Keep evaluation fixed and return to the inner loop.'],
    reflectConclude: ['CONCLUDE：收尾，把发现写清楚。', 'CONCLUDE: synthesize and write it up.'],
    reflectConcludeDetail: ['预算内已有可整理的信号。记录支持与限制，不把一次改进写成普适结论。', 'Summarize the signal within the budget. Record evidence and limits, not universal claims.'],
    memory: ['共享研究记忆', 'Shared research memory'],
    usingSkills: ['当前调用', 'SKILLS IN PLAY'],
    trialScore: ['本次测量 · 示意', 'This trial · simulated'],
    bestScore: ['当前保留 · 示意', 'Retained · simulated'],
    stepOutput: ['这一步留下', 'ARTIFACT'],
    progress: ['流程进度', 'Progress'],
    innerTakeawayTitle: ['内循环：优化一个假设。', 'Inner loop: improve one hypothesis. '],
    innerTakeaway: ['修改、测量，保留有效改进。', 'Modify, measure, keep what helps.'],
    outerTakeawayTitle: ['外循环：更新研究方向。', 'Outer loop: update the direction. '],
    outerTakeaway: ['解释结果，提出下一轮问题。', 'Interpret results. Ask the next question.'],
    disclaimer: ['流程演示，指标为示意数据。', 'Workflow demo. Metrics are illustrative.'],
    question: ['怎样让一个小模型更准确地识别手写数字？', 'How can a small model recognize handwritten digits more accurately?'],
    hypothesis1: ['适度增加模型容量，能否提高识别正确率？', 'Could a modest increase in model capacity improve accuracy?'],
    hypothesis2: ['训练时加入轻微旋转，能否改善歪斜数字的识别？', 'Could mild rotation during training improve recognition of tilted digits?']
  };
  // Scripted teaching values, deliberately unrelated to any real experiment.
  const frames = [
    {
      phase:'bootstrap', route:0, directive:'BOOTSTRAP', hypothesis:'question', h:'QUESTION', reflection:'waiting', loop:'loopWaiting',
      duration:3800, trial:null, best:null, verdict:'ready', skills:['research-orchestrator'], artifact:'research-question.md',
      label:['明确课题', 'FRAME THE QUESTION'],
      title:['从一个简单问题开始。', 'Start with a simple question.'],
      body:['目标很清楚：让小模型更准确地识别手写数字。Orchestrator 先确认数据、算力预算与评价标准。', 'The goal is simple: recognize handwritten digits more accurately. Orchestrator first establishes the data, compute budget, and evaluation criteria.']
    },
    {
      phase:'bootstrap', route:0, directive:'RESEARCH', hypothesis:'hypothesis1', h:'HYPOTHESIS 01', reflection:'waiting', loop:'loopWaiting',
      duration:4500, trial:null, best:null, verdict:'ready', skills:['deep-research','brainstorming-research-ideas','idea-evaluator'], artifact:'literature-notes.md → hypothesis-h1.md',
      label:['调研 → 构思 → 选题', 'LITERATURE → IDEAS → EVALUATION'],
      title:['先读文献，再提出假设。', 'Read first. Then form a hypothesis.'],
      body:['扫描相关方法、核验原文证据，筛选可行想法。这一轮先问：适度增加模型容量，会不会让识别更准确？', 'Survey approaches, check source evidence, and evaluate candidate ideas. Start with one testable question: could a slightly larger model recognize digits better?']
    },
    {
      phase:'protocol', route:1, directive:'FORGE', hypothesis:'hypothesis1', h:'HYPOTHESIS 01', reflection:'waiting', loop:'loopBaseline',
      duration:4500, trial:90.0, best:90.0, verdict:'baseline', skills:['experiment-forge'], artifact:'program.md + prepare.py + train.py',
      label:['任务包 → 锁定评估 → 基线', 'PACKAGE → LOCK EVALUATION → BASELINE'],
      title:['选一条适合本题的实验路线。', 'Choose a route for this question.'],
      body:['本例选择 Forge，便于把任务包独立交付运行；有现成可迭代代码时，也可直接调用 Autoresearch。固定评估与预算，提交计划后建立 90.0% 的示意基线。', 'This example chooses Forge for a standalone task package; an existing iterable codebase can use Autoresearch directly. Fix evaluation and budget, commit the plan, then establish the illustrative 90.0% baseline.']
    },
    {
      phase:'inner', route:2, directive:'EXPERIMENT', hypothesis:'hypothesis1', h:'HYPOTHESIS 01', reflection:'waiting', loop:'loopKeep',
      duration:4000, trial:91.2, best:91.2, verdict:'keep', skills:['autoresearch','run-experiment'], artifact:'results.tsv · trial 01 · keep',
      label:['内循环 1 · 第一次改动', 'INNER LOOP 1 · TRIAL 01'],
      title:['加宽网络，测量，再保留。', 'Widen the model. Measure. Keep.'],
      body:['Autoresearch 在可改范围内增加网络宽度，运行相同评估。示意分数从 90.0% 到 91.2%，通过检查后保留这次改动。', 'Autoresearch increases network width within scope and runs the same evaluation. The illustrative score goes from 90.0% to 91.2%; checks pass, so the change is retained.']
    },
    {
      phase:'inner', route:2, directive:'EXPERIMENT', hypothesis:'hypothesis1', h:'HYPOTHESIS 01', reflection:'waiting', loop:'loopRevert',
      duration:4000, trial:90.7, best:91.2, verdict:'revert', skills:['autoresearch','monitor-experiment'], artifact:'results.tsv · trial 02 · revert',
      label:['内循环 1 · 第二次改动', 'INNER LOOP 1 · TRIAL 02'],
      title:['再加深一层，反而退步。', 'An extra layer makes things worse.'],
      body:['下一次改动只有 90.7%，低于已保留的 91.2%。自动回滚到上一版，把失败与原因记入台账，而不是丢掉这次经验。', 'The next change scores 90.7%, below the retained 91.2%. Revert to the previous model and record the failed trial and its context instead of losing the lesson.']
    },
    {
      phase:'outer', route:2, directive:'DEEPEN', hypothesis:'hypothesis1', h:'REFLECTION 01', reflection:'error', loop:'loopReflect',
      duration:5800, trial:null, best:91.2, verdict:'reflect', skills:['research-orchestrator'], artifact:'findings.md · error analysis → DEEPEN',
      label:['外循环 · 从分数追问原因', 'OUTER LOOP · ASK WHY'],
      title:['不只调模型，还要重新提问。', 'Do more than tune. Ask a better question.'],
      body:['Orchestrator 汇总试验，发现歪斜数字仍集中出错。它选择 DEEPEN：下一轮不再一味加大模型，而是研究对旋转的鲁棒性。', 'Orchestrator reviews the trials and finds a pattern: tilted digits still fail. It chooses DEEPEN—not simply making the model bigger, but investigating rotation robustness.']
    },
    {
      phase:'protocol', route:2, directive:'NEW HYPOTHESIS', hypothesis:'hypothesis2', h:'HYPOTHESIS 02', reflection:'h2', loop:'loopReframe',
      duration:4500, trial:null, best:91.2, verdict:'protocol', skills:['research-orchestrator'], artifact:'protocol-h2.md → commit → run',
      label:['新假设 → 新计划 → 返回实验', 'NEW HYPOTHESIS → PLAN → EXPERIMENT'],
      title:['把反思变成下一轮实验。', 'Turn reflection into the next experiment.'],
      body:['提出 H2：训练时加入轻微旋转增强，能否减少这类错误？更新任务包并提交计划；仍用同一评估集，避免移动评价标准。', 'Form H2: could mild rotation augmentation during training reduce these errors? Update the task package and commit the plan. Keep the evaluation set unchanged.']
    },
    {
      phase:'inner', route:2, directive:'EXPERIMENT', hypothesis:'hypothesis2', h:'HYPOTHESIS 02', reflection:'h2', loop:'loopPending',
      duration:4000, trial:93.0, best:91.2, verdict:'pending', skills:['autoresearch','run-experiment'], artifact:'results.tsv · trial 03 · pending recheck',
      label:['内循环 2 · 检验新的假设', 'INNER LOOP 2 · TEST THE NEW IDEA'],
      title:['轻微旋转，看到了改进信号。', 'Mild rotation shows a promising signal.'],
      body:['只改变训练时的数据增强，得到示意分数 93.0%。先不把单次结果当作结论；安排确认跑，检查是否只是随机波动。', 'Change only training-time augmentation. The illustrative score reaches 93.0%. Do not treat one run as a conclusion: recheck whether the gain survives randomness.']
    },
    {
      phase:'inner', route:2, directive:'VERIFY', hypothesis:'hypothesis2', h:'HYPOTHESIS 02', reflection:'h2', loop:'loopConfirmed',
      duration:4500, trial:92.8, best:92.8, verdict:'keep', skills:['autoresearch'], artifact:'results.tsv · confirmation median · keep',
      label:['内循环 2 · 复测与防回归', 'INNER LOOP 2 · RECHECK & GUARD'],
      title:['复测后，再决定保留。', 'Recheck before keeping the change.'],
      body:['确认跑的示意中位数为 92.8%，仍高于此前的 91.2%，防回归检查通过。保留模型、代码与测量记录，不把偶然高点当作最终结果。', 'The illustrative confirmation median is 92.8%, still above 91.2%, with regression checks passing. Retain the model and its record—not the highest one-off score.']
    },
    {
      phase:'outer', route:2, directive:'CONCLUDE', hypothesis:'hypothesis2', h:'REFLECTION 02', reflection:'conclude', loop:'loopConclude',
      duration:4500, trial:null, best:92.8, verdict:'conclude', skills:['research-orchestrator'], artifact:'findings.md · evidence + limits → CONCLUDE',
      label:['外循环 · 判断何时收尾', 'OUTER LOOP · DECIDE WHEN TO CONCLUDE'],
      title:['证据与预算，一起决定下一步。', 'Let evidence and budget decide what comes next.'],
      body:['本例在预算内选择 CONCLUDE：整理哪些改动有效、哪些无效，以及结论适用的范围。如果证据不足，也可以继续深挖、拓宽或转向。', 'This example chooses CONCLUDE within its budget: summarize what helped, what failed, and the limits. If evidence were insufficient, it could deepen, broaden, or pivot instead.']
    },
    {
      phase:'writing', route:3, directive:'WRITE', hypothesis:'hypothesis2', h:'SYNTHESIS', reflection:'conclude', loop:'loopConclude',
      duration:4500, trial:null, best:92.8, verdict:'write', skills:['paper-production','paper-narrative','paper-writing'], artifact:'figures/ + paper-draft.md + citations',
      label:['综合发现 → 图表 → 论文草稿', 'SYNTHESIS → FIGURES → DRAFT'],
      title:['从实验记录，走到论文叙事。', 'Turn the experiment record into a paper.'],
      body:['把文献证据、两轮假设、成功与失败的试验组织成图表与草稿。每个结论回到记录，每一张图服务于问题，而不是只展示最高分。', 'Organize literature, both hypotheses, and successful and failed trials into figures and a draft. Trace each claim to its record; tell the research story, not just the highest score.']
    },
    {
      phase:'complete', route:3, directive:'DELIVER', hypothesis:'hypothesis2', h:'RESEARCH RECORD', reflection:'conclude', loop:'loopConclude',
      duration:4500, trial:null, best:92.8, verdict:'reviewed', skills:['research-review','pre-submission-reviewer'], artifact:'paper draft + figures + experiment ledger',
      label:['证据核验 → 写作评审 → 交付', 'EVIDENCE CHECK → WRITING REVIEW → DELIVERY'],
      title:['交付的不只是一个更高的分数。', 'Deliver more than a better score.'],
      body:['核验引用、评审论证与表达，交付可追溯的论文草稿、图表与实验台账。内循环让想法接受检验，外循环让研究持续获得方向。', 'Check citations and review the argument and writing. Deliver a traceable draft, figures, and experiment ledger. The inner loop tests ideas; the outer loop gives the research direction.']
    }
  ];
  const verdicts = {
    ready:['待开始','READY'], baseline:['基线','BASELINE'], keep:['保留 · KEEP','KEEP'],
    revert:['回滚 · REVERT','REVERT'], reflect:['反思 · DEEPEN','DEEPEN'],
    protocol:['计划已更新','PROTOCOL UPDATED'], pending:['待复测','RECHECK'],
    conclude:['综合收尾','CONCLUDE'], write:['组织叙事','WRITING'], reviewed:['草稿与记录就绪','DRAFT & RECORD READY']
  };
  let current = 0, elapsed = 0, lastTime = null, raf = null;
  let visible = false, wantsPlay = !reducedMotion.matches, finished = false;
  let lastFlow = '';
  const language = () => document.documentElement.lang === 'en' ? 1 : 0;
  const word = key => phrases[key][language()];
  const localized = pair => pair[language()];
  const running = () => wantsPlay && visible && !document.hidden && !finished;
  const score = value => value === null ? '—' : value.toFixed(1) + '%';
  const number = value => String(value).padStart(2, '0');

  function updateFlow() {
    const step = frames[current];
    const node = step.phase === 'inner' ? ['modify','run','decide'][Math.min(2, Math.floor(elapsed / step.duration * 3))] : '';
    if (node === lastFlow) return;
    lastFlow = node;
    player.querySelectorAll('[data-demo-node]').forEach(el => el.classList.toggle('is-active', el.dataset.demoNode === node));
  }
  function updateControls() {
    player.dataset.playing = String(running());
    byId('demo-toggle').textContent = word(finished ? 'again' : wantsPlay ? 'pause' : 'play');
    byId('demo-toggle').setAttribute('aria-pressed', String(wantsPlay && !finished));
    byId('demo-next').disabled = current === frames.length - 1;
  }
  function render(announce = false) {
    const step = frames[current];
    document.querySelectorAll('[data-demo-i18n]').forEach(el => el.textContent = word(el.dataset.demoI18n));
    player.dataset.step = String(current);
    player.dataset.phase = step.phase;
    player.querySelectorAll('[data-demo-route]').forEach(el => {
      const route = Number(el.dataset.demoRoute);
      el.classList.toggle('is-active', route === step.route);
      el.classList.toggle('is-done', route < step.route || finished);
      if (route === step.route) el.setAttribute('aria-current','step');
      else el.removeAttribute('aria-current');
    });
    byId('demo-directive').textContent = step.directive;
    byId('demo-hypothesis-id').textContent = step.h;
    byId('demo-hypothesis').textContent = word(step.hypothesis);
    byId('demo-loop-status').textContent = word(step.loop);
    const reflectionKey = {waiting:'reflectWaiting',error:'reflectError',h2:'reflectH2',conclude:'reflectConclude'}[step.reflection];
    byId('demo-reflection-title').textContent = word(reflectionKey);
    byId('demo-reflection-detail').textContent = word(reflectionKey+'Detail');
    byId('demo-step-count').textContent = number(current + 1)+' / '+frames.length;
    byId('demo-stage').textContent = localized(step.label);
    byId('demo-step-title').textContent = localized(step.title);
    byId('demo-step-body').textContent = localized(step.body);
    const fragment = document.createDocumentFragment();
    step.skills.forEach(name => { const el = document.createElement('code'); el.textContent = name; fragment.append(el); });
    byId('demo-skills').replaceChildren(fragment);
    byId('demo-trial-score').textContent = score(step.trial);
    byId('demo-best-score').textContent = score(step.best);
    byId('demo-verdict').textContent = localized(verdicts[step.verdict]);
    byId('demo-verdict').dataset.verdict = step.verdict;
    byId('demo-artifact-file').textContent = step.artifact;
    byId('demo-progress').value = String(current);
    byId('demo-progress').setAttribute('aria-valuetext',(current+1)+' / '+frames.length+': '+localized(step.title));
    byId('demo-progress-caption').textContent = number(current + 1)+' / '+frames.length;
    if (announce) byId('demo-announcement').textContent = localized(step.title)+' '+localized(step.body);
    updateControls();
    updateFlow();
  }
  function tick(now) {
    if (!running()) { raf = null; return; }
    if (lastTime !== null) elapsed += Math.min(100, now-lastTime);
    lastTime = now;
    if (elapsed >= frames[current].duration) {
      if (current === frames.length-1) {
        finished = true;
        wantsPlay = false;
        raf = null;
        render();
        return;
      }
      current += 1;
      elapsed = 0;
      render();
    }
    updateFlow();
    raf = requestAnimationFrame(tick);
  }
  function syncPlayback() {
    if (raf !== null) cancelAnimationFrame(raf);
    raf = null;
    lastTime = null;
    updateControls();
    if (running()) raf = requestAnimationFrame(tick);
  }
  function seek(value) {
    current = Math.max(0, Math.min(frames.length-1, Number(value)));
    elapsed = 0;
    finished = false;
    wantsPlay = false;
    render(true);
    syncPlayback();
  }
  function restart() {
    current = 0;
    elapsed = 0;
    finished = false;
    wantsPlay = true;
    render(true);
    syncPlayback();
  }
  byId('demo-toggle').addEventListener('click', () => {
    if (finished) return restart();
    wantsPlay = !wantsPlay;
    syncPlayback();
  });
  byId('demo-restart').addEventListener('click',restart);
  byId('demo-next').addEventListener('click',() => seek(current+1));
  byId('demo-progress').addEventListener('input',event => seek(event.target.value));
  document.addEventListener('research-language-change',() => render());
  document.addEventListener('visibilitychange',syncPlayback);
  reducedMotion.addEventListener('change',event => {
    if (event.matches) wantsPlay = false;
    render();
    syncPlayback();
  });
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(entries => {
      visible = entries[0].isIntersecting && entries[0].intersectionRatio >= 0.08;
      syncPlayback();
    }, {threshold:[0,0.08]}).observe(player);
  } else {
    visible = true;
  }
  render();
  syncPlayback();
})();
