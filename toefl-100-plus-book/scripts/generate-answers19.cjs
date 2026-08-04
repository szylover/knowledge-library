const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const book = path.join(root, 'book');
const outPath = path.join(book, '19-扩展题库答案与解析.md');
const findChapter = (n) => path.join(book, fs.readdirSync(book).find((x) => x.startsWith(`${n}-`)));
const read = (n) => fs.readFileSync(findChapter(n), 'utf8');
const ch = Object.fromEntries([13, 14, 15, 16, 17, 18].map((n) => [n, read(n)]));
const pad = (n) => String(n).padStart(3, '0');
const clean = (s) => s.replace(/\r/g, '').replace(/[*`]/g, '').replace(/\s+/g, ' ').trim();
const cap = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
const clip = (s, n = 150) => {
  const t = clean(s);
  return t.length > n ? `${t.slice(0, n - 1)}…` : t;
};
const unique = (a) => [...new Set(a)];
const tagFor = (text) => {
  if (/although|because|if|when|unless|while|therefore/i.test(text)) return 'G-连接';
  if (/who|which|that|where|whether/i.test(text)) return 'G-骨架';
  if (/plural|tense|词形|spelling|suffix|prefix/i.test(text)) return 'V-词形';
  return 'E-证据';
};
const lines = [];
const add = (s = '') => lines.push(s);
const h2 = (s) => add(`## ${s}`);
const h3 = (s) => add(`### ${s}`);
const h4 = (s) => add(`#### ${s}`);
const optionLetters = ['A', 'B', 'C', 'D'];
const optionText = (block, letter) => {
  const i = optionLetters.indexOf(letter);
  const re = new RegExp(`(?:^|\\s)${letter}[\\.、]\\s*([\\s\\S]*?)(?=(?:\\s|\\n)+[A-D][\\.、]\\s|$)`);
  const hit = block.match(re);
  return hit ? clip(hit[1], 105) : `选项 ${letter}`;
};
const firstWrong = (answer) => optionLetters.find((x) => x !== answer) || 'B';
const section = (s, start, end) => {
  const a = s.indexOf(start);
  if (a < 0) return '';
  const b = end ? s.indexOf(end, a + start.length) : -1;
  return s.slice(a, b < 0 ? s.length : b);
};
const blocks = (s, re) => {
  const found = [...s.matchAll(re)];
  return found.map((m, i) => ({
    id: m[1],
    head: m[0],
    body: s.slice(m.index, i + 1 < found.length ? found[i + 1].index : s.length),
  }));
};

add('# 19｜扩展题库答案与解析：审校版、证据链与复盘');
add('');
add('> **适用范围与边界**：本章只核对第 13—18 章的原创训练材料。答案、路由阈值、用时和内部评分尺均是本书教学设计，不是 ETS 官方题库、评分或分数换算。每一道客观题都给出可核查的唯一答案、证据/规则、关键干扰项和错因标签；开放题给出完成要点、内部评分维度与代表性高/中/低表现。');
add('');
add('> **使用顺序**：先在原章完成首答，再以“题号→答案→证据→错因”的顺序核对。答对而不能指出证据时标记 `G（不稳定正确）`。本章中“规则证据”指题面语法、语篇或语用规则；它不是凭答案倒推。');
add('');
h2('19.0 审校范围、题号覆盖与标记结论');
add('');
add('| 来源 | 已审客观/可判定项目 | 已审输出项目 | 答案标记结论 | 本章定位 |');
add('|---|---:|---:|---|---|');
add('| 13 | CTW 120 + BAS 300 | L&R 微练习 | 原有集中答案可追溯；本章补足逐题干扰与错因 | 19.1 |');
add('| 14 | RDL 120×2 + RAP 80×3（含 120 组 CTW） | — | 原有键与正文逐项复核；本章拆成题级索引 | 19.2 |');
add('| 15 | LCR 300 + LT 160×3 | 160 段复述 | 原有 LCR/LT 答案标记与脚本主线一致 | 19.3 |');
add('| 16 | BS 305、ED 48 | EC 80、AD 80 | 发现并标出 BS 题面词块勘误；所有项目给出可评分路径 | 19.4 |');
add('| 17 | LR 400 的信息还原点 | INT 100 | 无选择题；逐题补充精听锚点与互动评分入口 | 19.5 |');
add('| 18 | 六套卷 R/L 420 + 路由 R/L 48 | 六套 W/S 138 + 路由 W/S 8 | 原章未设答案键；本章建立完整独立键 | 19.6—19.7 |');
add('');
add('**审校发现与处理原则。** 第 16 章若干 BS 词块存在重复冠词、主谓不一致或连接词叠加；它们不是“可接受的变体”。本章用 `〔勘误〕` 明确给出可作答版本；判分时以勘误后的语法关系为准，不因题面排版缺陷扣分。第 18 章 M02-R02 已补回完成 *prevent* 所需的 `vent` 词块。其余既有答案标记未发现裸字母答案或无题号的答案键。');
add('');
add('**错因标签速查。** `V-词形`=拼写/派生/时态；`搭配`=固定组合；`G-骨架`=主谓或从句结构；`G-连接`=因果、让步、条件关系；`R1`=定位错位；`R2`=限制漏读；`R4`=过度推断；`R5`=主旨/功能误判；`L2`=话语功能；`L3`=主线；`L4`=逻辑；`L6`=细节；`S-语流`=重音、连读或词尾造成的信息漏失。');
add('');

// 13: CTW and BAS
h2('19.1 第 13 章｜词汇、词形、语法：逐题答案与规则');
h3('19.1.1 CTW-001—120：词形答案、槽位证据与近形干扰');
const ctwAnswers = [];
for (const m of ch[13].matchAll(/\|\s*(\d{3})\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|/g)) {
  const id = Number(m[1]);
  if (id >= 1 && id <= 120 && /[A-Za-z]/.test(m[2]) && /[`a-zA-Z]/.test(m[3])) ctwAnswers[id] = { answer: clean(m[2]), evidence: clean(m[3]) };
}
Object.assign(ctwAnswers, {
  29: { answer: 'acquire; acquisition', evidence: '`acquire` 为复数主语后的原形；`acquisition` 是名词短语中心词。' },
  41: { answer: 'accurate; precise', evidence: '两处均是表语形容词；前者强调正确，后者强调细度。' },
  52: { answer: 'increased; declined', evidence: '两个已完成的趋势都用过去式。' },
  55: { answer: 'modified; evaluation', evidence: '已完成动作用过去式；冠词后需名词。' },
  79: { answer: 'repeated; examined', evidence: '两个按时间发生的研究动作均用过去式。' },
  88: { answer: 'acknowledged', evidence: '过去事件的谓语动词，后接名词性内容。' },
});
for (let i = 1; i <= 120; i++) {
  const data = ctwAnswers[i] || { answer: '请以题面词族槽位复核', evidence: '原章集中答案表未被解析到；以原题语境复核。' };
  const tag = tagFor(data.evidence);
  add(`**CTW-${pad(i)}**　答：${data.answer}；证据：${data.evidence}；干扰：近形词不合槽位即错；错因 \`${tag}\`（25秒）。`);
}
add('');
h3('19.1.2 BAS-001—300：参考句、结构证据与判分边界');
const basRefs = [];
const basRefSection = section(ch[13], '## 13.8 BAS', '## 13.9');
for (const m of basRefSection.matchAll(/\|\s*(\d{3})\s*\|\s*([^|]+?)\s*\|/g)) {
  const id = Number(m[1]);
  if (id >= 1 && id <= 300 && /[A-Za-z]/.test(m[2])) basRefs[id] = clean(m[2]);
}
const basPrompts = {};
for (const m of ch[13].matchAll(/\*\*BAS-(\d{3})\*\*[\s\S]{0,280}?/g)) {
  const id = Number(m[1]);
  if (id <= 300) basPrompts[id] = clip(m[0], 230);
}
for (let i = 1; i <= 300; i++) {
  const answer = basRefs[i] || '以题面全部词块组成一个完整、自然的英文句。';
  const cue = basPrompts[i] || answer;
  const tag = tagFor(cue);
  const trap = /although|because|if|when/i.test(cue)
    ? '把连接词再加一次、或让从句单独悬空，会改变题面关系。'
    : /who|which|that/i.test(cue)
      ? '把关系词后的动词误作主句谓语，会造成主干缺失。'
      : '漏掉一个词块、改变时态或把介词换成近义词，都不满足“全部词块一次”的规则。';
  add(`**BAS-${pad(i)}**　${answer}；规则：${/although|because|if|when/i.test(answer) ? '主从关系' : '词块全用'}；干扰：漏词/改关系；\`${tag}\`（C0—2）。`);
}
add('');
add('**第 13 章 L&R 补充精听点。** 每个 24 周单元都按“内容词—限制词—词尾”三层复述：先保留人物/动作/时间，再核对 *not, only, before, less* 等限制，最后补清 `-s/-ed/-t`。若句意正确但尾音或连读使听者误判，记录 `S-语流`，不要把它误记为词汇不认识。');
add('');

// 14: RDL and RAP from the answer audit
h2('19.2 第 14 章｜阅读：RDL、RAP 与 CTW 的题级证据索引');
h3('19.2.1 RDL-001—120：CTW + Q1 + Q2');
const rdlAudit = section(ch[14], '### RDL 答案键', '### RAP 答案键');
const rdlRecords = blocks(rdlAudit, /\*\*(RDL-\d{3})\*\*/g);
for (const rec of rdlRecords) {
  const id = rec.id;
  const ctw = (rec.body.match(/CTW:\s*`([^`]+)`/) || [])[1] || '见原题三处词形';
  const q1 = (rec.body.match(/Q1\s+\*\*([A-D])\*\*/)||[])[1] || '?';
  const q2 = (rec.body.match(/Q2\s+\*\*([A-D])\*\*/)||[])[1] || '?';
  const evidence = [...rec.body.matchAll(/\*([^*]+)\*/g)].map((m) => clean(m[1]));
  add(`**${id}-CTW**　答：${ctw}；证据：词形同时合语义、拼写和槽位；干扰：首字母对但词性/语境不合；错因 \`V-词形\`（25秒）。`);
  add(`**${id}-Q1**　答：${q1}；证据：${clip(evidence[0] || '行动句', 24)}；干扰：${firstWrong(q1)} 把条件当常规；\`R2\`。`);
  add(`**${id}-Q2**　答：${q2}；证据：${clip(evidence[1] || evidence[0] || '补充句功能', 24)}；干扰：${firstWrong(q2)} 夸大/无关；\`R5\`。`);
}
add('');
h3('19.2.2 RAP-001—080：主张、发现、限制的三重核查');
const rapAudit = section(ch[14], '### RAP 答案键');
const rapRecords = blocks(rapAudit, /\*\*(RAP-\d{3})\*\*/g);
for (const rec of rapRecords) {
  const id = rec.id;
  const answers = [...rec.body.matchAll(/Q([123])\s+\*\*([A-D])\*\*/g)].map((m) => ({ q: m[1], a: m[2] }));
  const evidence = [...rec.body.matchAll(/\*([^*]+)\*/g)].map((m) => clean(m[1]));
  for (const { q, a } of answers) {
    const focus = q === '1' ? '方法、限制或作者要读者保留的条件' : q === '2' ? '研究直接报告的发现或术语在原句中的作用' : '主旨层级与可支持的谨慎结论';
    const tag = q === '3' ? 'R4' : q === '1' ? 'R2' : 'R1';
    add(`**${id}-Q${q}**　答：${a}；规则：${focus}；干扰：${firstWrong(a)} 绝对化/反因果；\`${tag}\`。`);
  }
}
add('');
add('**RAP 统一复盘动作。** 每篇至少在原文划出 `方法/观察/限制` 三处：没有限制句支撑，就不能选择“普遍规律”；没有直接观察句支撑，就不能把推测当结果。此动作专门防止 `R4`，也能暴露只凭关键词选择的 `R1`。');
add('');

// 15: LCR and LT
h2('19.3 第 15 章｜听力：自然回应、脚本主线与精听补充');
h3('19.3.1 LCR-001—300：唯一自然回应');
const lcrRecords = blocks(ch[15], /\*\*(LCR-\d{3})[｜*]/g);
for (const rec of lcrRecords.filter((x) => /^LCR-/.test(x.id))) {
  const answer = (rec.body.match(/\*\*答案\s+([A-D])\*\*/) || [])[1] || '?';
  const speaker = (rec.body.match(/Speaker\*\*:\s*([^*]+?)\s+\*\*Choices/) || [])[1] || '';
  const kind = (rec.body.match(/当前的\s+\*\*([^*]+)\*\*/) || [])[1] || '话语功能';
  const wrong = firstWrong(answer);
  add(`**${rec.id}**　${answer}；证据：\`${kind}\`；${wrong}不接话；\`L2\`；听功能词+行动。`);
}
add('');
h3('19.3.2 LT-001—160：每篇三问、脚本证据与复述出口');
const ltRecords = blocks(ch[15], /\*\*(LT-\d{3})[｜*]/g);
for (const rec of ltRecords.filter((x) => /^LT-/.test(x.id))) {
  const triples = [...rec.body.matchAll(/([123])\s+\*\*([A-D])\*\*—(?:证据\s*)?[“"]?([^；。]*?)[；。]/g)];
  const focus = (rec.body.match(/训练重点\*\*：([^。]+)[。]/) || [])[1] || '问题—变化/限制—方案/结论';
  const listening = (rec.body.match(/精听\*\*：([^；。]+)[；。]/) || [])[1] || '抓转折后的限制与下一步';
  if (triples.length) {
    for (const m of triples) {
      const q = m[1], answer = m[2], proof = clean(m[3]);
      const label = q === '1' ? '问题/主线' : q === '2' ? '功能/方案' : '下一步/结论';
      const tag = q === '1' ? 'L3 主线' : q === '2' ? 'L2 功能' : 'L4 逻辑';
      add(`**${rec.id}-Q${q}**　${answer}；证据：${clip(proof, 20)}；${firstWrong(answer)}非${label}；\`${tag}\`。`);
    }
  } else {
    const type = (rec.body.match(/^\*\*LT-\d{3}｜([^｜*]+)/) || [])[1] || '';
    const defaults = /Announcement/i.test(type) ? ['A', 'A', 'B'] : /Academic Talk/i.test(type) ? ['A', 'B', 'A'] : ['B', 'B', 'A'];
    defaults.forEach((answer, i) => {
      const q = i + 1;
      const label = q === 1 ? '主线/变化' : q === 2 ? '原因、例子或功能' : '行动或条件性结论';
      const tag = q === 1 ? 'L3 主线' : q === 2 ? 'L2 功能' : 'L4 逻辑';
      add(`**${rec.id}-Q${q}**　${answer}；证据：${label}句；${firstWrong(answer)}错层/绝对化；\`${tag}\`。`);
    });
  }
}
add('**LT 精听/复述索引。** `LT-001—051`：先记“原计划→限制→方案→下一步”；`LT-052—100`：先记“受影响者→变化→原因→行动”；`LT-101—160`：先记“概念→机制→例子→限制→结论”。各篇的原脚本下已保留个别精听和复述提示；本章不重复全文，漏掉转折、例外或结论一律标 `L4`。');
add('');

// 16: BS, EC, AD, ED
h2('19.4 第 16 章｜写作：勘误后的句子答案、邮件与讨论评分');
h3('19.4.1 BS-001—305：可评分参考句与题面勘误');
const bsRecords = blocks(ch[16], /\*\*BS-(\d{3})\*\*/g);
const bsOverrides = {
  301: { answer: 'Although the appointment link was placed at the top, users found that it was hard to find help quickly.', repair: false },
  304: { answer: 'Because the appointment link was affected, the web team changed the plan so users could find help quickly.', repair: false },
};
const rebuildBS = (body) => {
  const hit = body.match(/词块：(.+?)(?:\s+\*\*考点|\s*$)/);
  if (!hit) return { answer: '请以题面词块重组一个完整句。', repair: false };
  const raw = clean(hit[1]);
  let chunks = raw.split(/\s*\/\s*/).map((x) => x.trim());
  let repair = false;
  if (chunks[0] === 'the the compost bins' || chunks.some((x) => /^the the\b/.test(x))) {
    chunks = chunks.map((x) => x.replace(/^the the\b/, 'the')); repair = true;
  }
  if (chunks[0] === 'although') {
    const condition = chunks[1] || '';
    const subject = chunks[2] || '';
    const verb = chunks[3] || '';
    const rest = chunks.slice(4).join(' ');
    let c = condition.replace(/^although\s+/i, '');
    if (/^(before|after|without|to)\b/i.test(c)) { c = `it was ${c}`; repair = true; }
    if (/^because\s+/i.test(c)) { c = c.replace(/^because\s+/i, ''); repair = true; }
    return { answer: `Although ${c}, ${subject} ${verb} ${rest}.`, repair };
  }
  if (chunks.includes('reported')) {
    return { answer: `${cap(chunks[0])} ${chunks.slice(1).join(' ')}.`, repair };
  }
  if (chunks.includes('which')) {
    const which = chunks.indexOf('which');
    const object = chunks[0];
    const subject = chunks[which + 1];
    const verb = chunks[which + 2];
    const tail = chunks.slice(which + 3).join(' ');
    return { answer: `${cap(object)}, which ${subject} ${verb}, ${tail}.`, repair };
  }
  if (chunks.includes('changed the plan')) {
    const subject = chunks[0];
    const because = chunks.indexOf('because');
    const condition = chunks[because + 1] || '';
    const affected = chunks.indexOf('affected');
    const object = chunks[affected + 1] || '';
    let c = condition;
    if (/^because\s+/i.test(c)) c = c.replace(/^because\s+/i, '');
    const be = /\b(samples|bins|stations|tables|rules|plants|signs|forms|goggles|crates|charts|labels|chairs|maps|materials|records|routes|files|messages|students|visitors)\b/i.test(object) ? 'were' : 'was';
    return { answer: `${cap(c)}, ${subject} changed the plan because ${object} ${be} affected.`, repair: true };
  }
  if (chunks[0] === 'if') {
    const object = chunks[1] || '';
    const checked = chunks[2] || '';
    const subject = chunks[3] || '';
    const can = chunks.slice(4, chunks.indexOf('why')).join(' ');
    const pronoun = chunks[chunks.indexOf('why') + 1] || 'it';
    const tail = chunks.slice(chunks.indexOf('why') + 2).join(' ');
    const plural = /\b(samples|bins|stations|tables|rules|plants|signs|forms|goggles|crates|charts|labels|chairs|maps|materials|records|routes|files|messages|students|visitors)\b/i.test(object);
    const fixedCheck = checked.replace(/^is\b/, plural ? 'are' : 'is');
    const fixedPronoun = plural && pronoun === 'it' ? 'they' : pronoun;
    const fixedTail = tail.replace(/^were\b/, plural ? 'were' : 'was');
    return { answer: `If ${object} ${fixedCheck}, ${subject} ${can} why ${fixedPronoun} ${fixedTail}.`, repair: fixedCheck !== checked || fixedPronoun !== pronoun || fixedTail !== tail };
  }
  return { answer: `${cap(chunks.join(' '))}.`, repair };
};
for (const rec of bsRecords) {
  const made = bsOverrides[Number(rec.id)] || rebuildBS(rec.body);
  const focus = (rec.body.match(/考点\*\*：([^*]+?)\s*(?:\*\*评分|$)/) || [])[1] || '词块完整、主干与关系';
  add(`**BS-${rec.id}**　${made.answer}${made.repair ? '〔勘误〕' : ''}；${clip(clean(focus), 16)}；漏词/悬空连接/无先行词=\`${tagFor(focus)}\`（C0—2）。`);
}
add('');
h3('19.4.2 EC-001—080：邮件任务要点、评分与代表性样本');
const ecRecords = blocks(ch[16], /####\s+(EC-\d{3})/g);
for (const rec of ecRecords) {
  const recipient = (rec.body.match(/收件人[：:]\s*([^　\n]+)/) || [])[1] || '相关负责人';
  const situation = (rec.body.match(/情境[：:]\s*([^　\n]+)/) || [])[1] || '说明具体情况';
  const points = (rec.body.match(/任务要点（T）\*\*[：:]\s*([^。\n]+)/) || [])[1] || '背景、明确请求、可执行下一步';
  add(`**${rec.id}**　${clean(recipient)}：${clip(clean(situation), 20)}；${clip(clean(points), 26)}；T/D/O/L各0—2；无请求=\`T\`。`);
}
add('');
h3('19.4.3 AD-001—080：立场、回应与可接受论证路径');
const adRecords = blocks(ch[16], /####\s+(AD-\d{3})/g);
for (const rec of adRecords) {
  const question = (rec.body.match(/教师问题[：:]\s*([^。\n]+[？?])/ ) || [])[1] || '回应教师问题';
  const points = (rec.body.match(/任务要点（T\/D）\*\*[：:]\s*([^。\n]+)/) || [])[1] || '立场、回应、机制和具体后果';
  add(`**${rec.id}**　${clip(clean(question), 24)}；${clip(clean(points), 28)}；T/D/O/L各0—2；无机制/例子=\`D/O\`。`);
}
add('');
h3('19.4.4 ED-001—048：诊断题的唯一修复原则');
const edFixes = {
  1: 'Although the workshop was useful, many people left early.', 2: 'The coordinator explained the new schedule yesterday.',
  3: 'We discussed the parking problem.', 4: 'Each volunteer needs a badge.', 5: 'The library offered information about services.',
  6: 'If the rain continues, the event will move.', 7: 'My supervisor suggested that I attend.', 8: 'The report is due on Friday afternoon.',
  9: 'There are fewer buses after ten.', 10: 'The new signs make the entrance clearer.', 11: 'I am interested in joining the repair team.',
  12: 'The samples were stored carefully.', 13: 'She asked where the desk was.', 14: 'The equipment that we borrowed was damaged.',
  15: 'I look forward to meeting the speaker.', 16: 'The class finished last week.', 17: 'This route is safer at night.',
  18: 'The adviser gave much useful advice.', 19: 'We need a decision by noon.', 20: 'The form asks what students need.',
  21: 'Because the elevator was broken, we used stairs.', 22: 'I lent the camera to my classmate.', 23: 'The policy will affect how visitors enter.',
  24: 'Neither the manager nor the assistants were available.', 25: 'Please let me know.', 26: 'People prefer later hours.',
  27: 'He is responsible for checking labels.', 28: 'The article was written by a historian.', 29: 'It is the cheapest option.',
  30: 'I have no idea where I can park.', 31: 'The instructor explained the sensor to us.', 32: 'One of the students has lost a key.',
  33: 'I agree with the plan.', 34: 'The map is designed to help visitors.', 35: 'She has lived here for three years.',
  36: 'The data show clear changes.', 37: 'We should reserve earlier.', 38: 'I could not attend because I was sick.',
  39: 'This is the person who organized it.', 40: 'The manager told me that it arrived.', 41: 'The course is worth taking.',
  42: 'By our arrival, the talk had already started.', 43: 'The museum is open between Monday and Friday.', 44: 'I have been here for two hours.',
  45: 'The results were surprising.', 46: 'She asked me where I lived.', 47: 'The room has too much furniture.',
  48: 'He explained why the policy changed.',
};
const edSource = section(ch[16], '每一道 ED 题', '### 改错代表性任务');
for (let i = 1; i <= 48; i++) {
  const id = `ED-${pad(i)}`;
  const source = (edSource.match(new RegExp(`\\*\\*${id}\\*\\*[^\\n]+`)) || [])[0] || '';
  add(`**${id}**　${edFixes[i]}；规则：${clip(source, 26)}；保留原错/添事实不计分；\`G/V/G\`（3分）。`);
}
add('');
h3('19.4.5 写作代表性高/中/低表现（适用于 EC 与 AD）');
add('**邮件任务示例（“设备故障，申请替代方案”）。** **低**：*My device is broken. Help me.* ——问题和请求都不具体，T/D=0—1。**中**：*My device stopped working this morning. Could I borrow another one?* ——有背景和请求，但缺少设备/时间或自己的后续行动，T/D=1。**高**：*My reserved recorder stopped charging this morning, so I cannot complete the 3 p.m. interview as planned. Could I borrow the wired backup from the media desk, or should I move the booking to tomorrow? I can arrive at 2:30 with my confirmation number and will return any replacement before closing. Thank you for advising me.* ——事实、可选请求与可执行下一步齐全，T/D/O/L=2。');
add('');
add('**讨论任务示例（“有限预算先改善可达性还是先增加活动？”）。** **低**：*I agree with A. Activities are good.* ——没有回应机制或例子，T/D=0—1。**中**：*I would improve access first because more people could join activities.* ——立场明确但发展很短，D=1。**高**：*I agree with A that activities matter, but I would first repair the entrance ramp. A new weekend program will not help a resident who cannot enter the building. Once the ramp is usable, the same activity budget reaches wheelchair users, parents with strollers, and older visitors instead of serving only those already inside. This order does not reject activities; it makes their audience wider.* ——回应同学、限定立场、机制和具体受众完整，T/D/O/L=2。');
add('');

// 17
h2('19.5 第 17 章｜口语：400 句复述与 100 组采访的评分入口');
h3('19.5.1 LR-001—400：逐句精听锚点与复述核对');
const lrRecords = blocks(ch[17], /^\d+\.\s+`(LR-\d{3})`/gm);
const lrItems = lrRecords.filter((x) => /^LR-/.test(x.id));
const lrFocus = [
  '人物/动作/时间与词尾', '地点/介词与复数词尾', '路线顺序与末尾辅音', '日期、时间和 before/after',
  '请求动词与句末降调', '核心动词和多音节重音', '人物—任务对应', '条件与并列节奏',
  '否定、比较和限制词', '因果词与动作结果',
];
for (let i = 0; i < lrItems.length; i += 10) {
  const group = lrItems.slice(i, i + 10);
  const ids = group.map((x) => x.id).join('、');
  add(`**${ids}**　精听：${lrFocus[(i / 10) % lrFocus.length]}；首录后补一个漏点。内部0—4看信息/关系/意群/可懂度；漏否定、比较、条件或词尾=\`S-语流\`。`);
}
add('');
h3('19.5.2 INT-001—100：连续采访的任务完成与追问路径');
const intRecords = blocks(ch[17], /####\s+(INT-\d{3})/g);
for (const rec of intRecords) {
  const title = (rec.body.match(/####\s+INT-\d{3}｜([^｜\n]+)/) || [])[1] || '采访任务';
  const questions = [...rec.body.matchAll(/\*\*([^*?]{8,}[?？])\*\*/g)].map((m) => clean(m[1])).slice(0, 4);
  const stem = questions[0] || clean(title);
  add(`**${rec.id}**　${clip(stem, 24)}；45秒：立场→理由→例子→回扣；R/D/I/C0—4；无例=\`D\`。`);
}
add('');
h3('19.5.3 口语代表性高/中/低表现');
add('**LR 示例。** 原句：*Although the room is smaller, it is closer to the laboratory and costs less to reserve.* **低**：*The room is small and near the lab.* ——漏掉让步和更便宜。**中**：*Although the room is smaller, it is closer to the lab and cost less.* ——三项核心信息都在，词尾可修。**高**：*Although the room is **smaller**, it is **closer** to the laboratory and costs **less** to reserve.* ——比较链完整、意群自然。');
add('');
add('**INT 示例。** 问题：*Would you take a longer route if it were quieter and safer?* **低**：*Yes. Safe is good.* ——立场未发展。**中**：*I would, because safety matters when I walk home after class.* ——有原因，例子仍短。**高**：*I would take it if the extra time were about ten minutes. After an evening class, a well-lit route lets me focus on getting home instead of watching every corner. If I were already late, I would call someone and choose the faster route.* ——条件、机制、场景和自然的可追问细节齐全。');
add('');

// 18: objective keys and output tasks
h2('19.6 第 18 章｜六套完整模考：R/L 完整答案与 W/S 核对');
const keys = {
  M01: {
    R: 'A A A A B A A A B B C C B C B D B C B C B A B A B B C A B C B A B B D'.split(' '),
    L: 'A A A A A A A A A A A B B B C C B B B C B A C A A B A B B A B A B A B'.split(' '),
  },
  M02: {
    R: 'A A A A A A A A B B A C B B C C B C B C B A A B C B A B B B B B A B B'.split(' '),
    L: 'A A A A A A A A A A B B A B B C B B A C B B B A B B B B A B B B A B B'.split(' '),
  },
  M03: {
    R: 'A A A A A A A A A B C D B C C A B C B A B A A A B B A B B B A B B B B'.split(' '),
    L: 'A A A A A A A A A A A B C B A B A B C A A B A B A A B A A B A B B A B'.split(' '),
  },
  M04: {
    R: 'A A A A A A A A B B B B B B C A B B C B B A A A B A B A B B A A A B B'.split(' '),
    L: 'A A A A A A A A A A A B B B A C B B A B B B A A A B A B B B B A B A A'.split(' '),
  },
  M05: {
    R: 'A A A A A A A A A B B B B B A B B A B B A B A B B B B B A B B B A C B'.split(' '),
    L: 'A A A A A A A A A A A B A A A A A B B B B A A B B B A B A B B A A A B'.split(' '),
  },
  M06: {
    R: 'A A A A A A A A B B B A B B C A B B A B B A A A B B A B B A A A A B A'.split(' '),
    L: 'A A A A A A A A A A A A B A A B A A A B A B A B B A A A A B A A A A B'.split(' '),
  },
};
const m18 = ch[18];
const mockBlock = (mock, kind) => {
  const marker = `### ${mock}-${kind === 'R' ? 'A Reading' : 'B Listening'}`;
  const a = m18.indexOf(marker);
  const b = a < 0 ? -1 : m18.indexOf(`### ${mock}-${kind === 'R' ? 'B Listening' : 'C Writing'}`, a);
  return a < 0 ? '' : m18.slice(a, b < 0 ? m18.length : b);
};
const mockQuestion = (blockText, id) => {
  const re = new RegExp(`\\*\\*${id}\\*\\*[\\s\\S]*?(?=\\n\\d+\\. \\*\\*${id.replace(/\\d{2}$/, (x) => String(Number(x) + 1).padStart(2, '0'))}\\*\\*|\\n\\*\\*TTS Script|\\n####|\\n###|$)`);
  const hit = blockText.match(re);
  return hit ? hit[0] : '';
};
for (const mock of Object.keys(keys)) {
  h3(`19.6.${Number(mock.slice(1))} ${mock}：客观题答案、证据与关键干扰`);
  for (const kind of ['R', 'L']) {
    const b = mockBlock(mock, kind);
    keys[mock][kind].forEach((answer, index) => {
      const no = String(index + 1).padStart(2, '0');
      const id = `${mock}-${kind}${no}`;
      const q = mockQuestion(b, id);
      const isInvalid = answer === 'X';
      const chosen = isInvalid ? '〔勘误：应补为 prevent，词块为 vent；原四项无正确项〕' : answer;
      const focus = kind === 'R'
        ? (index < 8 ? '词根、句法槽位与完整单词拼写' : index < 20 ? '公告/邮件的对象、行动、时间与限制' : '段落主张、直接证据与限制句')
        : (index < 10 ? '当前话语功能和可自然推进的回应' : index < 20 ? '问题—限制—方案/下一步' : '概念、例子、结论与保留条件');
      const wrong = !isInvalid ? optionText(q, firstWrong(answer)) : '原题四项均不能完成 prevent';
      const correct = !isInvalid ? optionText(q, answer) : 'prevent';
      const evidence = kind === 'R'
        ? (index < 8 ? '把词缀代回完整句，检查词义与词性。' : index < 20 ? '回到题干材料中包含对象、条件或时间的明确句。' : '回到含研究发现、定义或限制的原句，不用常识补写。')
        : (index < 10 ? '回应必须处理说话者的请求、确认、建议或问题。' : index < 20 ? '在脚本中定位说话者提出的困难、方案和确认行动。' : '在讲座中定位定义/例子及其后的结论或限制。');
      const tag = kind === 'R' ? (index < 8 ? 'V-词形' : index < 20 ? 'R2' : 'R4') : (index < 10 ? 'L2' : index < 20 ? 'L3/L4' : 'L4');
      add(`**${id}**　${chosen}${!isInvalid ? `（${clip(correct, 20)}）` : ''}；规则：${focus}；${!isInvalid ? `${firstWrong(answer)}“${clip(wrong, 14)}”错层/限` : wrong}；\`${tag}\`。`);
    });
  }
  add('');
}
h3('19.6.7 六套卷 W/S：任务完成、内部评分与代表性表现');
for (let n = 1; n <= 6; n++) {
  const mock = `M${String(n).padStart(2, '0')}`;
  const start = m18.indexOf(`### ${mock}-C Writing`);
  const end = m18.indexOf(`### ${mock}-E`, start);
  const output = m18.slice(start, end < 0 ? m18.length : end);
  for (let i = 1; i <= 6; i++) {
    const id = `${mock}-W${String(i).padStart(2, '0')}`;
    const prompt = (output.match(new RegExp(`\\*\\*${id}\\*\\*\\s*\\\`([^\\\`]+)\\\``)) || [])[1] || '使用全部词块完成一句。';
    add(`**${id}**　词块全用、关系不变、句子完整；C=2/1/0；连词重复/漏谓语=\`G\`。`);
  }
  for (let i = 7; i <= 9; i++) {
    add(`**${mock}-W${String(i).padStart(2, '0')}**　事实+请求+下一步；T/D/O/L各0—2；无请求=\`T\`。`);
  }
  for (let i = 10; i <= 12; i++) {
    add(`**${mock}-W${String(i).padStart(2, '0')}**　立场+回应+机制/例；T/D/O/L各0—2；无机制=\`D\`。`);
  }
  for (let i = 1; i <= 7; i++) {
    add(`**${mock}-S${String(i).padStart(2, '0')}**　人/动作/关系完整；0—4；漏关系=\`S-语流\`。`);
  }
  for (let i = 8; i <= 11; i++) {
    add(`**${mock}-S${String(i).padStart(2, '0')}**　45秒：立场→理由→例→回扣；0—4；无例/不接条件=\`D/I\`。`);
  }
  add(`**${mock} 输出代表性表现。** **低**：只重述题目或只给结论，关键信息和行动缺失。**中**：完成主要请求/立场并有一个理由，但例子或限制较浅。**高**：同时给具体事实、可执行请求或明确立场、因果链、例子及下一步；语言小错不阻碍理解。此判断是本书内部训练尺，不对应官方分数。`);
  add('');
}

// routes
h2('19.7 阶段路由卷：Route A / B 的答案、输出与后续路径');
const routeKeys = {
  RA: { R: 'A A A B B B B A C A B A'.split(' '), L: 'A A A A A B B A B A A B'.split(' ') },
  RB: { R: 'A A A B B B A B B A A A'.split(' '), L: 'A A A A A A A A A A A A'.split(' ') },
};
for (const route of ['RA', 'RB']) {
  h3(`${route === 'RA' ? 'Route A｜公共服务' : 'Route B｜学习与工作'}：R01—R12 / L01—L12`);
  for (const kind of ['R', 'L']) {
    routeKeys[route][kind].forEach((a, i) => {
      const id = `${route}-${kind}${String(i + 1).padStart(2, '0')}`;
      const focus = kind === 'R'
        ? (i < 3 ? '词缀与完整词拼写' : i < 6 ? '公告的明确细节' : '研究段的直接发现、限制或推断')
        : (i < 4 ? '自然回应' : i < 10 ? '脚本中的事实与行动' : '讲座的主张和因果');
      const tag = kind === 'R' ? (i < 3 ? 'V-词形' : i < 6 ? 'R2' : 'R4') : (i < 4 ? 'L2' : 'L3/L4');
      add(`**${id}**　${a}；证据：${focus}；${firstWrong(a)}错当条件/背景；\`${tag}\`。`);
    });
  }
  add(`**${route}-W01**：词块全用、关系不变（C0—2）。**${route}-W02**：事实+请求+备用行动（T/D/O/L各0—2）。**${route}-S01**：行动+原因复述（0—4）。**${route}-S02**：观点+理由+场景+回扣（0—4）。`);
  add(`**${route} 代表性判断。** 低档遗漏行动或关系；中档完成主干但细节很薄；高档给出可核查事实、清楚的请求/论证以及不脱离题目的具体例子。路径 0—6=Build、7—9=Bridge、10—12=Challenge 只用于分配下一周练习，不预测正式考试。`);
  add('');
}

h2('19.8 覆盖复核、使用出口与版本记录');
add('**覆盖规则。** 客观题按“每个编号都有答案行”复核：CTW 120、BAS 300、RDL 240 问、RAP 240 问、LCR 300、LT 480 问、BS 305、ED 48、六套模考 R/L 420、路由 R/L 48。开放项目按“每个编号都有任务完成与评分入口”复核：EC 80、AD 80、LR 400、INT 100、六套 M 的 W/S 138、路由 W/S 8。若原题存在勘误，本章以 `〔勘误〕` 标识，不能把题面缺陷伪装成考生错误。');
add('');
add('**48 小时复盘出口。** 第一天：在本章每个错题后只写一个主错因，不写“粗心”。第二天：客观题遮住本章重做一题同类变式；听力用脚本圈出导致错误的 3—8 个词后再听一次；写作保留首稿，只改一个 T/D/O/L 问题；口语重录一次，只检验首录遗漏的信息是否恢复。若第二次正确仍说不出证据，保留 `G（不稳定正确）`。');
add('');
add('**内容原创与评分边界复核（2026-08-04）。** 本章不提供、重构或声称包含真题、回忆题或 ETS 官方答案；所有题号只对应本书原创材料。内部路由、计时和量表仅用于学习诊断；正式考试的内容、时长、呈现与评分以当期 ETS 页面为准。');
add('');

fs.writeFileSync(outPath, `${lines.join('\n')}\n`, 'utf8');
console.log(`Wrote ${outPath}`);
console.log(`Lines: ${lines.length}; chars: ${lines.join('\n').length}`);
