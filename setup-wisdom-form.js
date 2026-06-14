// ============================================================
// Form 2: Experience & Lessons — "Share what you learned"
// ============================================================
// Pure stories, lessons, and wisdom. No technical how-tos.
// WHY do you think this way? What shaped your expertise?
// ============================================================

var FORM_ID = 'PASTE_NEW_FORM_ID_HERE';

function setupWisdomForm() {
  var form = FormApp.openById(FORM_ID);

  form.setTitle('Share what you learned');
  form.setDescription(
    'This form captures your stories, lessons, and wisdom. The experiences that shaped how you think. Pick a category and tell us what you learned.'
  );
  form.setConfirmationMessage(
    'Thank you! Your experience has been recorded. Feel free to submit again for a different category.'
  );

  while (form.getItems().length > 0) {
    form.deleteItem(0);
  }

  // =================================================================
  // PAGE 1: Category picker
  // =================================================================
  var categoryQuestion = form.addMultipleChoiceItem()
    .setTitle('What area are you sharing experience about?')
    .setHelpText('Pick one. You will get questions specific to this area.')
    .setRequired(true);

  // =================================================================
  // UI/UX DESIGN
  // =================================================================
  var pageUIUX = form.addPageBreakItem().setTitle('UI/UX Design Lessons');
  pageUIUX.setHelpText('Share stories and wisdom from your design experience.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about a design decision that taught you something important.')
    .setHelpText('A specific project, screen, or interaction. What was the challenge? What did you learn?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What do you notice first when you look at someone else\'s design?')
    .setHelpText('After 20 years, what patterns, red flags, or quality signals jump out instantly?');

  form.addParagraphTextItem()
    .setTitle('What is the most common mistake junior designers make?')
    .setHelpText('The thing you see over and over.');

  form.addParagraphTextItem()
    .setTitle('What design principle do you follow that most designers ignore?')
    .setHelpText('Your contrarian view on design.');

  form.addParagraphTextItem()
    .setTitle('How do you know when a design is "done"?')
    .setHelpText('What signals tell you to stop iterating?');

  form.addParagraphTextItem()
    .setTitle('What did you believe about design early in your career that you now think is wrong?');

  // =================================================================
  // PRODUCT DEVELOPMENT
  // =================================================================
  var pageProduct = form.addPageBreakItem().setTitle('Product Development Lessons');
  pageProduct.setHelpText('Share stories and wisdom from building products.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about a product decision that changed everything.')
    .setHelpText('A feature you cut, a pivot, a technical bet that paid off or failed.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you decide what to build next and what to kill?')
    .setHelpText('Your prioritization philosophy. How do you say no to good ideas?');

  form.addParagraphTextItem()
    .setTitle('What is the biggest technical mistake you made, and what did it teach you?');

  form.addParagraphTextItem()
    .setTitle('What do you wish you knew about shipping products before you started?');

  form.addParagraphTextItem()
    .setTitle('How do you build something users actually want vs what you think they want?');

  // =================================================================
  // BUSINESS
  // =================================================================
  var pageBusiness = form.addPageBreakItem().setTitle('Business Lessons');
  pageBusiness.setHelpText('Share stories and wisdom from the business side.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about a business decision that taught you something important.')
    .setHelpText('Pricing, partnerships, fundraising. A real moment.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What business lesson do most builders completely miss?');

  form.addParagraphTextItem()
    .setTitle('What is the hardest business conversation you have had, and how did you handle it?');

  form.addParagraphTextItem()
    .setTitle('How do you think about revenue and sustainability for a product?');

  // =================================================================
  // MARKETING & BRANDING
  // =================================================================
  var pageMarketing = form.addPageBreakItem().setTitle('Marketing & Branding Lessons');
  pageMarketing.setHelpText('Share stories and wisdom about growth and brand.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about how you grew an audience or got your first users.')
    .setHelpText('What specifically did you do? What worked? What flopped?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you build a brand that people remember?')
    .setHelpText('Not just a logo. The feeling, the voice, the positioning.');

  form.addParagraphTextItem()
    .setTitle('What marketing tactic worked surprisingly well for you?');

  form.addParagraphTextItem()
    .setTitle('What is the biggest marketing mistake builders make?');

  // =================================================================
  // BUILDING WITH AI
  // =================================================================
  var pageAI = form.addPageBreakItem().setTitle('Building with AI Lessons');
  pageAI.setHelpText('Share what you have learned using AI to build products.');

  form.addParagraphTextItem()
    .setTitle('How has AI changed the way you build products?')
    .setHelpText('What is fundamentally different? What stays the same?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is the biggest mistake people make when building with AI?');

  form.addParagraphTextItem()
    .setTitle('What should stay human and what should be automated?');

  form.addParagraphTextItem()
    .setTitle('What would you tell someone using AI to build for the first time?');

  // =================================================================
  // CORPORATE EXPERIENCE
  // =================================================================
  var pageCorporate = form.addPageBreakItem().setTitle('Corporate Experience Lessons');
  pageCorporate.setHelpText('Share what you learned inside large organizations.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about something you learned inside a large company that surprised you.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you navigate politics and get buy-in for ideas?');

  form.addParagraphTextItem()
    .setTitle('What corporate skills transfer to building your own thing? What does not?');

  form.addParagraphTextItem()
    .setTitle('What is the biggest difference between building in a company vs on your own?');

  // =================================================================
  // DESIGN SYSTEMS
  // =================================================================
  var pageDesignSystems = form.addPageBreakItem().setTitle('Design Systems Lessons');
  pageDesignSystems.setHelpText('Share wisdom about building systems that scale.');

  form.addParagraphTextItem()
    .setTitle('How do you build a design system that actually gets used?')
    .setHelpText('What makes the difference between adopted and ignored?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('When should a team invest in a system vs just ship screens?');

  form.addParagraphTextItem()
    .setTitle('What is the biggest mistake teams make with design systems?');

  // =================================================================
  // TEACHING
  // =================================================================
  var pageTeaching = form.addPageBreakItem().setTitle('Teaching & Mentoring Lessons');
  pageTeaching.setHelpText('Share wisdom about teaching and growing others.');

  form.addParagraphTextItem()
    .setTitle('How do you give feedback that helps instead of discourages?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is the most common mistake mentors make?');

  form.addParagraphTextItem()
    .setTitle('How do you know when someone truly understands vs just memorized?');

  // =================================================================
  // CULTURAL CONTEXT
  // =================================================================
  var pageCultural = form.addPageBreakItem().setTitle('Cultural Context Lessons');
  pageCultural.setHelpText('Share what you learned about building for local markets.');

  form.addParagraphTextItem()
    .setTitle('What did you learn the hard way about building for local users?')
    .setHelpText('Something you assumed would work but did not.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('Top 3 things someone must know before building for the Vietnamese market?');

  // =================================================================
  // SOLO FOUNDER
  // =================================================================
  var pageSolo = form.addPageBreakItem().setTitle('Solo Founder Lessons');
  pageSolo.setHelpText('Share wisdom about building alone.');

  form.addParagraphTextItem()
    .setTitle('How do you manage energy, not just time?')
    .setHelpText('Creative blocks, burnout, motivation.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What keeps you going when nothing seems to be working?');

  // =================================================================
  // CONTENT
  // =================================================================
  var pageContent = form.addPageBreakItem().setTitle('Content & Storytelling Lessons');
  pageContent.setHelpText('Share wisdom about creating content that resonates.');

  form.addParagraphTextItem()
    .setTitle('What makes a tutorial good vs forgettable?')
    .setHelpText('After consuming and creating thousands. What separates the best?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you tell the story of a product in a way that resonates?');

  // =================================================================
  // SUCCESS & FAILURE
  // =================================================================
  var pageSuccessFailure = form.addPageBreakItem().setTitle('Success & Failure Lessons');
  pageSuccessFailure.setHelpText('Share turning points and hard-won lessons.');

  form.addParagraphTextItem()
    .setTitle('What is the most important turning point in your career?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is your biggest failure, and what did it teach you?');

  form.addParagraphTextItem()
    .setTitle('What is your biggest success, and why did it work?');

  form.addParagraphTextItem()
    .setTitle('If you could start over, what would you do differently?');

  form.addParagraphTextItem()
    .setTitle('What did you believe 10 years ago that you now think is wrong?');

  // =================================================================
  // CLOSING
  // =================================================================
  var pageClosing = form.addPageBreakItem().setTitle('Wrapping up');
  pageClosing.setHelpText('Final questions.');

  form.addParagraphTextItem()
    .setTitle('What was the context of this experience?')
    .setHelpText('Company stage, team size, year, solo vs startup vs corporate.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What changed after you applied this lesson? Include numbers if possible.')
    .setHelpText('"Conversion 2% to 8%", "Saved 3 months", "Reduced churn by half"')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('Do you have a repeatable framework for this?')
    .setHelpText('"Every time I face [situation], I do [steps]."');

  form.addParagraphTextItem()
    .setTitle('What do you believe that most people disagree with?');

  form.addParagraphTextItem()
    .setTitle('What skill from one domain unexpectedly helped in another?');

  form.addTextItem()
    .setTitle('Name this lesson (2-5 words)')
    .setRequired(true);

  form.addTextItem()
    .setTitle('Sticky-note version, one sentence.')
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('What type of knowledge is this?')
    .setChoiceValues([
      'A principle - universal truth',
      'A pattern - advice for a specific situation',
      'A contrarian view - against common wisdom',
      'A war story - lesson from experience',
      'An evolution - how your thinking changed'
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('Who needs this most?')
    .setChoiceValues([
      'Complete beginner',
      'Someone with some experience',
      'Someone building something real',
      'Someone about to launch',
      'Mid-career professional',
      'Anyone at any level'
    ])
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('Any quote, metaphor, or analogy?');

  form.addParagraphTextItem()
    .setTitle('What book, person, or experience shaped this?');

  form.addParagraphTextItem()
    .setTitle('Supporting files (paste links)');

  form.addParagraphTextItem()
    .setTitle('Anything else?');

  // =================================================================
  // Wire navigation
  // =================================================================
  categoryQuestion.setChoices([
    categoryQuestion.createChoice('UI/UX Design', pageUIUX),
    categoryQuestion.createChoice('Product Development', pageProduct),
    categoryQuestion.createChoice('Business', pageBusiness),
    categoryQuestion.createChoice('Marketing & Branding', pageMarketing),
    categoryQuestion.createChoice('Building with AI Tools', pageAI),
    categoryQuestion.createChoice('Corporate Experience', pageCorporate),
    categoryQuestion.createChoice('Design Systems & Scaling', pageDesignSystems),
    categoryQuestion.createChoice('Teaching & Mentoring', pageTeaching),
    categoryQuestion.createChoice('Cultural Context & Local Markets', pageCultural),
    categoryQuestion.createChoice('Solo Founder Survival', pageSolo),
    categoryQuestion.createChoice('Content & Storytelling', pageContent),
    categoryQuestion.createChoice('Lessons from Success & Failure', pageSuccessFailure)
  ]);

  pageProduct.setGoToPage(pageClosing);
  pageBusiness.setGoToPage(pageClosing);
  pageMarketing.setGoToPage(pageClosing);
  pageAI.setGoToPage(pageClosing);
  pageCorporate.setGoToPage(pageClosing);
  pageDesignSystems.setGoToPage(pageClosing);
  pageTeaching.setGoToPage(pageClosing);
  pageCultural.setGoToPage(pageClosing);
  pageSolo.setGoToPage(pageClosing);
  pageContent.setGoToPage(pageClosing);
  pageSuccessFailure.setGoToPage(pageClosing);

  Logger.log('Wisdom form complete!');
  Logger.log('Edit: ' + form.getEditUrl());
  Logger.log('Published: ' + form.getPublishedUrl());
}
