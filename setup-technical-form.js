// ============================================================
// Form 1: Technical Knowledge — "Share how you do it"
// ============================================================
// Pure craft and technique. No stories, no wisdom.
// HOW do you actually do the work?
// ============================================================

var FORM_ID = '1sfMlOtmHG-AgzPIhlsb43O9Oz6QKmvsLH08TEG5hB3w';

function setupTechnicalForm() {
  var form = FormApp.openById(FORM_ID);

  form.setTitle('Share how you do it');
  form.setDescription(
    'This form captures your technical craft: specific techniques, step-by-step methods, and practical how-tos. Pick a category and share how you actually do the work.'
  );
  form.setConfirmationMessage(
    'Thank you! Your technical knowledge has been recorded. Feel free to submit again for a different category.'
  );

  while (form.getItems().length > 0) {
    form.deleteItem(0);
  }

  // =================================================================
  // PAGE 1: Category picker
  // =================================================================
  var categoryQuestion = form.addMultipleChoiceItem()
    .setTitle('What area are you sharing technical knowledge about?')
    .setHelpText('Pick one. You will get specific how-to questions for that area.')
    .setRequired(true);

  // =================================================================
  // UI/UX DESIGN
  // =================================================================
  var pageUIUX = form.addPageBreakItem().setTitle('UI/UX Design Techniques');
  pageUIUX.setHelpText('Share your specific design methods and processes.');

  form.addParagraphTextItem()
    .setTitle('How do you choose a color palette for a new product?')
    .setHelpText('Your actual steps. Brand values? Competitor analysis? Mood board? How many colors? How do you test contrast?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you set up typography hierarchy?')
    .setHelpText('Font choices, sizes, weights, scales. Your system for headings, body, captions.');

  form.addParagraphTextItem()
    .setTitle('How do you approach layout, spacing, and responsive design?')
    .setHelpText('Grid system? Spacing scale? What breaks first on mobile and how do you fix it?');

  form.addParagraphTextItem()
    .setTitle('How do you design a form that people actually complete?')
    .setHelpText('Field order, validation timing, error messages, progress indicators.');

  form.addParagraphTextItem()
    .setTitle('How do you hand off designs to developers?')
    .setHelpText('Specs, annotations, tokens, documentation.');

  form.addParagraphTextItem()
    .setTitle('How do you run a quick user test in under 30 minutes?')
    .setHelpText('Who, how many, what you ask, how you record findings.');

  form.addParagraphTextItem()
    .setTitle('How do you design for accessibility without sacrificing aesthetics?')
    .setHelpText('Contrast, keyboard nav, screen readers, touch targets.');

  // =================================================================
  // PRODUCT DEVELOPMENT
  // =================================================================
  var pageProduct = form.addPageBreakItem().setTitle('Product Development Techniques');
  pageProduct.setHelpText('Share how you build, scope, and ship products.');

  form.addParagraphTextItem()
    .setTitle('How do you scope an MVP? Walk through your actual steps.')
    .setHelpText('From idea to "this is what we build first." Your real process.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you write a product spec developers can build from?')
    .setHelpText('Sections, detail level, edge cases. Share your template if you have one.');

  form.addParagraphTextItem()
    .setTitle('How do you set up analytics to know if a feature works?')
    .setHelpText('What you track, what tools, how you define success before building.');

  form.addParagraphTextItem()
    .setTitle('How do you structure a backlog that stays useful?')
    .setHelpText('Categorization, prioritization, grooming, archiving.');

  form.addParagraphTextItem()
    .setTitle('How do you handle technical debt?')
    .setHelpText('When to fix, when to ignore. Your framework.');

  form.addParagraphTextItem()
    .setTitle('How do you run a productive build cycle or sprint?')
    .setHelpText('Cadence, standups, demos, async updates. What works?');

  // =================================================================
  // BUSINESS
  // =================================================================
  var pageBusiness = form.addPageBreakItem().setTitle('Business Techniques');
  pageBusiness.setHelpText('Share how you handle the business side.');

  form.addParagraphTextItem()
    .setTitle('How do you calculate if a product idea is financially viable?')
    .setHelpText('Unit economics, market size, pricing model. Your back-of-napkin process.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you set pricing? Walk through your process.')
    .setHelpText('Competitor pricing, value-based, testing price points.');

  form.addParagraphTextItem()
    .setTitle('How do you structure a pitch?')
    .setHelpText('To investors, partners, or customers. What goes first? What do you emphasize?');

  form.addParagraphTextItem()
    .setTitle('How do you negotiate a deal or partnership?')
    .setHelpText('Your preparation, approach, and style.');

  form.addParagraphTextItem()
    .setTitle('What financial numbers do you look at and why?')
    .setHelpText('Revenue, costs, margins, burn rate, runway. What matters most?');

  // =================================================================
  // MARKETING & BRANDING
  // =================================================================
  var pageMarketing = form.addPageBreakItem().setTitle('Marketing & Branding Techniques');
  pageMarketing.setHelpText('Share how you grow audience and build brand.');

  form.addParagraphTextItem()
    .setTitle('How do you write a landing page that converts?')
    .setHelpText('Structure, headline formula, CTA, social proof. What goes above the fold?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is your step-by-step launch playbook?')
    .setHelpText('Pre-launch, launch day, post-launch. Timeline, channels, messaging.');

  form.addParagraphTextItem()
    .setTitle('How do you create content consistently?')
    .setHelpText('Batching, scheduling, repurposing, templates.');

  form.addParagraphTextItem()
    .setTitle('How do you build an email list and write emails people open?')
    .setHelpText('Lead magnets, subject lines, frequency, segmentation.');

  form.addParagraphTextItem()
    .setTitle('How do you measure if marketing is working?')
    .setHelpText('Which metrics, how you attribute, when to pivot.');

  // =================================================================
  // BUILDING WITH AI
  // =================================================================
  var pageAI = form.addPageBreakItem().setTitle('Building with AI Techniques');
  pageAI.setHelpText('Share your specific AI workflow and methods.');

  form.addParagraphTextItem()
    .setTitle('Share 3-5 specific prompt patterns that work consistently for you.')
    .setHelpText('Actual structures you reuse. Show real examples, not vague tips.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you structure a project for AI-assisted development?')
    .setHelpText('File organization, documentation, context management.');

  form.addParagraphTextItem()
    .setTitle('How do you review and validate AI-generated output?')
    .setHelpText('Your quality check process. What mistakes does AI consistently make?');

  form.addParagraphTextItem()
    .setTitle('What is your daily AI workflow?')
    .setHelpText('Which tools for which tasks, morning to evening.');

  form.addParagraphTextItem()
    .setTitle('How do you handle AI hallucinations and errors?')
    .setHelpText('Your strategy for catching wrong information or bad code.');

  // =================================================================
  // DESIGN SYSTEMS
  // =================================================================
  var pageDesignSystems = form.addPageBreakItem().setTitle('Design Systems Techniques');
  pageDesignSystems.setHelpText('Share how you build scalable systems.');

  form.addParagraphTextItem()
    .setTitle('How do you name components and organize a library?')
    .setHelpText('Naming convention, folder structure, categorization.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you define and manage design tokens?')
    .setHelpText('Colors, spacing, typography, shadows. Structure and format.');

  form.addParagraphTextItem()
    .setTitle('How do you handle component variants and states?')
    .setHelpText('Default, hover, active, disabled, error, loading.');

  form.addParagraphTextItem()
    .setTitle('How do you document a component so others use it correctly?')
    .setHelpText('Usage examples, dos and don\'ts, prop tables.');

  // =================================================================
  // TEACHING
  // =================================================================
  var pageTeaching = form.addPageBreakItem().setTitle('Teaching & Mentoring Techniques');
  pageTeaching.setHelpText('Share how you teach and create learning experiences.');

  form.addParagraphTextItem()
    .setTitle('How do you structure a lesson or tutorial from scratch?')
    .setHelpText('Outline first? Start with exercise? Build up or break down?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you create exercises that build skill, not just test memory?');

  form.addParagraphTextItem()
    .setTitle('How do you scaffold difficulty so learners stay challenged but not overwhelmed?');

  form.addParagraphTextItem()
    .setTitle('Share 2-3 analogies you use to explain technical concepts.')
    .setHelpText('What makes a good analogy vs a confusing one?');

  // =================================================================
  // CULTURAL CONTEXT
  // =================================================================
  var pageCultural = form.addPageBreakItem().setTitle('Local Market Techniques');
  pageCultural.setHelpText('Share specific methods for building for local markets.');

  form.addParagraphTextItem()
    .setTitle('What specific design patterns work differently for Vietnamese or SEA users?')
    .setHelpText('Payment, navigation, trust signals, content layout.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you localize a product beyond just translating text?')
    .setHelpText('Cultural nuances, imagery, color meaning, interaction patterns.');

  // =================================================================
  // SOLO FOUNDER
  // =================================================================
  var pageSolo = form.addPageBreakItem().setTitle('Solo Founder Techniques');
  pageSolo.setHelpText('Share practical methods for managing everything alone.');

  form.addParagraphTextItem()
    .setTitle('How do you prioritize when you are designer, developer, marketer, and support?')
    .setHelpText('What comes first? What gets skipped? Your system.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What do you outsource, automate, or skip entirely?')
    .setHelpText('Practical decisions about what deserves your attention.');

  form.addParagraphTextItem()
    .setTitle('What tools and systems keep you organized as a solo founder?')
    .setHelpText('Project management, communication, finance, time tracking.');

  // =================================================================
  // CONTENT
  // =================================================================
  var pageContent = form.addPageBreakItem().setTitle('Content & Storytelling Techniques');
  pageContent.setHelpText('Share methods for creating educational content.');

  form.addParagraphTextItem()
    .setTitle('How do you explain a complex concept to someone who has never seen it?')
    .setHelpText('Your technique: analogies, examples, progressive disclosure?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is your process for creating educational content?')
    .setHelpText('Outline, write, edit, record. Your workflow.');

  form.addParagraphTextItem()
    .setTitle('How do you decide what level to teach at?')
    .setHelpText('Beginner, intermediate, expert. How do you calibrate?');

  // =================================================================
  // CLOSING
  // =================================================================
  var pageClosing = form.addPageBreakItem().setTitle('Final details');
  pageClosing.setHelpText('A few quick details to organize this knowledge.');

  form.addTextItem()
    .setTitle('Name this technique (2-5 words)')
    .setHelpText('"The 3-font rule", "Napkin math for pricing", "The 5-second test"')
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How hard is this to learn?')
    .setChoiceValues([
      'Beginner - anyone can do this today',
      'Intermediate - needs some background',
      'Advanced - requires significant experience',
      'Expert - took years to develop'
    ])
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('Common mistakes when trying this technique?')
    .setHelpText('What goes wrong without guidance?');

  form.addParagraphTextItem()
    .setTitle('Tools or resources needed?')
    .setHelpText('Software, books, templates.');

  form.addParagraphTextItem()
    .setTitle('Supporting files (paste links)');

  // =================================================================
  // Wire navigation
  // =================================================================
  categoryQuestion.setChoices([
    categoryQuestion.createChoice('UI/UX Design', pageUIUX),
    categoryQuestion.createChoice('Product Development', pageProduct),
    categoryQuestion.createChoice('Business', pageBusiness),
    categoryQuestion.createChoice('Marketing & Branding', pageMarketing),
    categoryQuestion.createChoice('Building with AI Tools', pageAI),
    categoryQuestion.createChoice('Design Systems & Scaling', pageDesignSystems),
    categoryQuestion.createChoice('Teaching & Mentoring', pageTeaching),
    categoryQuestion.createChoice('Cultural Context & Local Markets', pageCultural),
    categoryQuestion.createChoice('Solo Founder Survival', pageSolo),
    categoryQuestion.createChoice('Content & Storytelling', pageContent)
  ]);

  pageProduct.setGoToPage(pageClosing);
  pageBusiness.setGoToPage(pageClosing);
  pageMarketing.setGoToPage(pageClosing);
  pageAI.setGoToPage(pageClosing);
  pageDesignSystems.setGoToPage(pageClosing);
  pageTeaching.setGoToPage(pageClosing);
  pageCultural.setGoToPage(pageClosing);
  pageSolo.setGoToPage(pageClosing);
  pageContent.setGoToPage(pageClosing);

  Logger.log('Technical form complete!');
  Logger.log('Edit: ' + form.getEditUrl());
  Logger.log('Published: ' + form.getPublishedUrl());
}
