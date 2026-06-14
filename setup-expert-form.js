// ============================================================
// Codepet Expert Knowledge — Combined Form v5
// ============================================================
// One form, two parts per domain:
//   Part 1: Technical craft (HOW you do it)
//   Part 2: Wisdom & story (WHY you think this way)
//
// Expert picks a domain → sees craft questions → then story questions → closing.
// ============================================================

var FORM_ID = '1sfMlOtmHG-AgzPIhlsb43O9Oz6QKmvsLH08TEG5hB3w';

function setupExpertKnowledgeForm() {
  var form = FormApp.openById(FORM_ID);

  form.setTitle('Your experience, in your words');
  form.setDescription(
    'You have spent years building things most people only talk about. This form turns that experience into something the next generation can learn from. Pick a topic, share the real stuff: how you actually do the work, and the stories behind why you do it that way. One topic per round. Come back anytime.'
  );
  form.setConfirmationMessage(
    'Thank you! Your knowledge has been recorded. Feel free to submit again for a different category.'
  );

  while (form.getItems().length > 0) {
    form.deleteItem(0);
  }

  // =================================================================
  // PAGE 1: Domain picker
  // =================================================================
  var domainQuestion = form.addMultipleChoiceItem()
    .setTitle('What area are you sharing about today?')
    .setHelpText('Pick one category. You will get questions specific to this area.')
    .setRequired(true);

  // =================================================================
  // UI/UX DESIGN
  // =================================================================
  var pageUIUX = form.addPageBreakItem().setTitle('UI/UX Design');

  // -- Part 1: Craft --
  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('Share your specific techniques, step-by-step methods, and practical processes. Be as detailed as possible.');

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
    .setHelpText('Field order, validation timing, error messages, progress indicators — your rules.');

  form.addParagraphTextItem()
    .setTitle('How do you hand off designs to developers?')
    .setHelpText('Specs, annotations, tokens, documentation — what do you include?');

  form.addParagraphTextItem()
    .setTitle('How do you run a quick user test in under 30 minutes?')
    .setHelpText('Who, how many, what you ask, how you record findings.');

  // -- Part 2: Wisdom --
  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

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

  // =================================================================
  // PRODUCT DEVELOPMENT
  // =================================================================
  var pageProduct = form.addPageBreakItem().setTitle('Product Development');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you actually build and ship products?');

  form.addParagraphTextItem()
    .setTitle('How do you scope an MVP — your actual step-by-step process?')
    .setHelpText('From idea to "this is what we build first." Not theory — your real steps.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you write a product spec that developers can build from?')
    .setHelpText('Sections, detail level, edge cases. Share your template if you have one.');

  form.addParagraphTextItem()
    .setTitle('How do you set up analytics to know if a feature is working?')
    .setHelpText('What you track, what tools, how you define success before building.');

  form.addParagraphTextItem()
    .setTitle('How do you structure a backlog that does not become a graveyard?')
    .setHelpText('Categorization, prioritization, grooming, archiving.');

  form.addParagraphTextItem()
    .setTitle('How do you handle technical debt — when to fix vs ignore?')
    .setHelpText('Your framework for deciding when messy code is fine vs when it needs cleanup.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

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

  // =================================================================
  // ENGINEERING
  // =================================================================
  var pageEngineering = form.addPageBreakItem().setTitle('Engineering');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('Share your specific engineering methods, architecture decisions, and technical processes.');

  form.addParagraphTextItem()
    .setTitle('How do you choose a tech stack for a new project?')
    .setHelpText('What factors do you weigh? Speed vs scalability? Familiarity vs best tool? How do you evaluate?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you structure a codebase so it stays maintainable as it grows?')
    .setHelpText('File organization, naming conventions, architecture patterns. What keeps code clean at scale?');

  form.addParagraphTextItem()
    .setTitle('How do you debug a problem you have never seen before?')
    .setHelpText('Your systematic process. Where do you start? How do you narrow down? What tools do you use?');

  form.addParagraphTextItem()
    .setTitle('How do you set up CI/CD and deployment for a new project?')
    .setHelpText('Your workflow from code commit to production. What tools, what steps, what safeguards?');

  form.addParagraphTextItem()
    .setTitle('How do you write code that other developers can understand and maintain?')
    .setHelpText('Documentation, comments, naming, code review practices.');

  form.addParagraphTextItem()
    .setTitle('How do you approach performance optimization?')
    .setHelpText('When do you optimize? How do you find bottlenecks? What is your process?');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about a technical decision that had major consequences.')
    .setHelpText('An architecture choice, a library decision, a shortcut that cost you. What happened?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is the most expensive engineering mistake you have made?')
    .setHelpText('Time, money, users lost. What went wrong and what did you learn?');

  form.addParagraphTextItem()
    .setTitle('What engineering principle do you follow that most developers skip?');

  form.addParagraphTextItem()
    .setTitle('When is it okay to ship messy code, and when is it not?')
    .setHelpText('Your philosophy on speed vs quality.');

  // =================================================================
  // BUSINESS DEVELOPMENT
  // =================================================================
  var pageBusiness = form.addPageBreakItem().setTitle('Business Development');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('Share your methods for growing a business: strategy, partnerships, sales, and revenue.');

  form.addParagraphTextItem()
    .setTitle('How do you calculate whether a product idea is financially viable?')
    .setHelpText('Your back-of-napkin process. Unit economics, market size, pricing model.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you set pricing? Walk through your actual process.')
    .setHelpText('Competitor pricing, value-based, testing price points — what do you do?');

  form.addParagraphTextItem()
    .setTitle('How do you structure a pitch — to investors, partners, or customers?')
    .setHelpText('Your framework. What goes first? What do you emphasize?');

  form.addParagraphTextItem()
    .setTitle('How do you read basic financials — what numbers matter?')
    .setHelpText('Revenue, costs, margins, burn rate — what you look at and why.');

  form.addParagraphTextItem()
    .setTitle('How do you find and close partnerships or business deals?')
    .setHelpText('Your approach to outreach, relationship building, negotiation, and closing.');

  form.addParagraphTextItem()
    .setTitle('How do you identify and pursue new business opportunities?')
    .setHelpText('Market research, customer discovery, competitive gaps. Your process for finding where to grow.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about a business decision that taught you something important.')
    .setHelpText('Pricing, partnerships, fundraising — a real moment.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What business lesson do most builders completely miss?');

  form.addParagraphTextItem()
    .setTitle('What is the hardest business conversation you have had, and how did you handle it?');

  // =================================================================
  // MARKETING & BRANDING
  // =================================================================
  var pageMarketing = form.addPageBreakItem().setTitle('Marketing & Branding');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you get people to notice, care, and buy?');

  form.addParagraphTextItem()
    .setTitle('How do you write a landing page that converts?')
    .setHelpText('Structure, headline formula, CTA placement, social proof. What goes above the fold?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you launch a product — your step-by-step playbook?')
    .setHelpText('Pre-launch, launch day, post-launch. Timeline, channels, messaging.');

  form.addParagraphTextItem()
    .setTitle('How do you create content consistently without burning out?')
    .setHelpText('Batching, scheduling, repurposing, templates — your workflow.');

  form.addParagraphTextItem()
    .setTitle('How do you measure if marketing is working?')
    .setHelpText('Which metrics, how you attribute, when to double down vs pivot.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about how you grew an audience or got your first users.')
    .setHelpText('What specifically did you do? What worked? What flopped?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you build a brand that people remember?')
    .setHelpText('Not just a logo — the feeling, the voice, the positioning.');

  form.addParagraphTextItem()
    .setTitle('What is the biggest marketing mistake builders make?');

  // =================================================================
  // BUILDING WITH AI
  // =================================================================
  var pageAI = form.addPageBreakItem().setTitle('Building with AI Tools');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you use AI to build products?');

  form.addParagraphTextItem()
    .setTitle('Share 3-5 specific prompt patterns that work consistently for you.')
    .setHelpText('Actual prompt structures you reuse, not vague tips. Show real examples.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you structure a project for AI-assisted development?')
    .setHelpText('File organization, documentation, context management — what makes AI work better?');

  form.addParagraphTextItem()
    .setTitle('How do you review and validate AI-generated output?')
    .setHelpText('Your quality check process. What do you look for? What mistakes does AI make?');

  form.addParagraphTextItem()
    .setTitle('What is your daily AI workflow — which tools for which tasks?')
    .setHelpText('Morning to evening, how and when you use AI.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('How has AI changed the way you build products?')
    .setHelpText('What is fundamentally different? What stays the same?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is the biggest mistake people make when building with AI?')
    .setHelpText('Over-reliance, under-use, wrong expectations — what do you see?');

  form.addParagraphTextItem()
    .setTitle('What should stay human and what should be automated?');

  // =================================================================
  // CORPORATE EXPERIENCE
  // =================================================================
  var pageCorporate = form.addPageBreakItem().setTitle('Corporate Experience');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you navigate and succeed inside large organizations?');

  form.addParagraphTextItem()
    .setTitle('How do you get buy-in for your ideas in a large organization?')
    .setHelpText('Your process for selling ideas internally. Stakeholder management, presentations, timing.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you manage up, down, and sideways in a team?')
    .setHelpText('Working with managers, reports, and peers — your approach.');

  form.addParagraphTextItem()
    .setTitle('How do you run a meeting that is not a waste of time?')
    .setHelpText('Your rules for productive meetings. What do you always do? What do you never do?');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('Tell a story about something you learned inside a large company that surprised you.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What corporate skills transfer to building your own thing? What does not?');

  form.addParagraphTextItem()
    .setTitle('What is the biggest difference between building in a company vs on your own?');

  // =================================================================
  // DESIGN SYSTEMS
  // =================================================================
  var pageDesignSystems = form.addPageBreakItem().setTitle('Design Systems & Scaling');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you build systems that scale?');

  form.addParagraphTextItem()
    .setTitle('How do you name components and organize a component library?')
    .setHelpText('Naming convention, folder structure, categorization.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you define and manage design tokens?')
    .setHelpText('Colors, spacing, typography, shadows — structure and format.');

  form.addParagraphTextItem()
    .setTitle('How do you document a component so others use it correctly?')
    .setHelpText('Usage examples, dos and don\'ts, prop tables.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('How do you build a design system that actually gets used?')
    .setHelpText('What makes the difference between adopted and ignored?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('When should a team invest in a system vs just ship screens?');

  // =================================================================
  // TEACHING & MENTORING
  // =================================================================
  var pageTeaching = form.addPageBreakItem().setTitle('Teaching & Mentoring');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you teach and create learning experiences?');

  form.addParagraphTextItem()
    .setTitle('How do you structure a lesson or tutorial from scratch?')
    .setHelpText('Outline first? Start with exercise? Build up or break down?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you create exercises that build skill, not just test memory?');

  form.addParagraphTextItem()
    .setTitle('How do you explain technical concepts using analogies? Share 2-3 you use.')
    .setHelpText('What makes a good analogy vs a confusing one?');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

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
  var pageCultural = form.addPageBreakItem().setTitle('Cultural Context & Local Markets');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you build for local markets?');

  form.addParagraphTextItem()
    .setTitle('What specific design patterns work differently for Vietnamese or SEA users?')
    .setHelpText('Payment, navigation, trust signals, content layout — concrete differences.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you localize a product beyond just translating text?')
    .setHelpText('Cultural nuances, imagery, color meaning, interaction patterns.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('What did you learn the hard way about building for local users?')
    .setHelpText('Something you assumed would work because it works elsewhere, but did not.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('Top 3 things someone must know before building for the Vietnamese market?');

  // =================================================================
  // SOLO FOUNDER
  // =================================================================
  var pageSolo = form.addPageBreakItem().setTitle('Solo Founder Survival');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you manage everything alone?');

  form.addParagraphTextItem()
    .setTitle('How do you prioritize when you are designer, developer, marketer, and support?')
    .setHelpText('What comes first? What gets skipped? Your decision process.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What do you outsource, automate, or skip entirely?')
    .setHelpText('Practical decisions about what deserves your attention.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('How do you manage energy, not just time?')
    .setHelpText('Creative blocks, burnout, motivation — your approach.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What keeps you going when nothing seems to be working?');

  // =================================================================
  // CONTENT & STORYTELLING
  // =================================================================
  var pageContent = form.addPageBreakItem().setTitle('Content & Storytelling');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you create content that teaches and resonates?');

  form.addParagraphTextItem()
    .setTitle('How do you explain a complex concept to someone who has never seen it?')
    .setHelpText('Your technique: analogies, examples, progressive disclosure?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is your process for creating educational content?')
    .setHelpText('Outline, write, edit, record — your workflow.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('What makes a tutorial good vs forgettable?')
    .setHelpText('After consuming and creating thousands — what separates the best?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you decide what level to teach at?')
    .setHelpText('Beginner, intermediate, expert — how do you calibrate?');

  // =================================================================
  // SUCCESS & FAILURE
  // =================================================================
  var pageSuccessFailure = form.addPageBreakItem().setTitle('Lessons from Success & Failure');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('HOW do you handle success and failure practically?');

  form.addParagraphTextItem()
    .setTitle('How do you run a post-mortem after something fails?')
    .setHelpText('Your process for analyzing what went wrong without blame.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you decide whether to persist or pivot after a failure?')
    .setHelpText('Your framework for knowing when to keep going vs change direction.');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('What is the most important turning point in your career?')
    .setHelpText('A moment where everything shifted.')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What is your biggest failure, and what did it teach you?');

  form.addParagraphTextItem()
    .setTitle('What did you believe 10 years ago that you now think is wrong?')
    .setHelpText('How your thinking evolved.');

  // =================================================================
  // FOUNDER'S MINDSET
  // =================================================================
  var pageFounder = form.addPageBreakItem().setTitle('Founder\'s Mindset');

  form.addSectionHeaderItem()
    .setTitle('SECTION 1: Technical Expertise')
    .setHelpText('Share your methods for thinking, deciding, and leading as a founder.');

  form.addParagraphTextItem()
    .setTitle('How do you make decisions when you have incomplete information?')
    .setHelpText('Your framework for deciding with uncertainty. How much data do you need? When do you trust your gut?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('How do you set vision and direction for a product or company?')
    .setHelpText('Your process for defining where you are going and getting others to follow.');

  form.addParagraphTextItem()
    .setTitle('How do you manage your own psychology as a founder?')
    .setHelpText('Doubt, fear, loneliness, imposter syndrome, comparison. What are your coping strategies?');

  form.addParagraphTextItem()
    .setTitle('How do you balance building for today vs planning for the future?')
    .setHelpText('Short-term survival vs long-term vision. How do you hold both?');

  form.addParagraphTextItem()
    .setTitle('How do you know when to ask for help vs figure it out yourself?')
    .setHelpText('Advisors, mentors, co-founders, community. When and how do you seek support?');

  form.addSectionHeaderItem()
    .setTitle('SECTION 2: Experience & Lessons Learned')
    .setHelpText('Share stories, lessons, mistakes, and insights from your real experience.');

  form.addParagraphTextItem()
    .setTitle('What is the hardest thing about being a founder that nobody talks about?')
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('What belief or mindset shift made the biggest difference in your journey?')
    .setHelpText('A moment where your thinking fundamentally changed.');

  form.addParagraphTextItem()
    .setTitle('What advice would you give to someone starting their founder journey today?')
    .setHelpText('The thing you wish someone had told you on day one.');

  form.addParagraphTextItem()
    .setTitle('How has your definition of success changed over time?')
    .setHelpText('What did success mean 10 years ago vs now?');

  form.addParagraphTextItem()
    .setTitle('What do you do when you feel like quitting?')
    .setHelpText('Your honest process for getting through the darkest moments.');

  // =================================================================
  // CLOSING (all domains land here)
  // =================================================================
  var pageClosing = form.addPageBreakItem().setTitle('Wrapping up');
  pageClosing.setHelpText('Final questions — applies to all domains.');

  form.addParagraphTextItem()
    .setTitle('Do you have a repeatable framework or process for what you shared?')
    .setHelpText('"Every time I face [situation], I do [steps]."');

  form.addParagraphTextItem()
    .setTitle('What do you believe that most people disagree with?')
    .setHelpText('Your contrarian view.');

  form.addParagraphTextItem()
    .setTitle('What skill from one domain unexpectedly helped in another?')
    .setHelpText('Cross-domain transfers.');

  form.addTextItem()
    .setTitle('Name this lesson (2-5 words)')
    .setRequired(true);

  form.addTextItem()
    .setTitle('Sticky-note version — one sentence.')
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('What type of knowledge is this?')
    .setChoiceValues([
      'A principle — universal truth',
      'A technique — specific method or process',
      'A pattern — advice for a specific situation',
      'A contrarian view — against common wisdom',
      'A war story — lesson from experience',
      'An evolution — how your thinking changed'
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How hard is this to learn?')
    .setChoiceValues([
      'Beginner — anyone can do this today',
      'Intermediate — needs some background',
      'Advanced — requires significant experience',
      'Expert — took years to develop'
    ])
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('Any quote, metaphor, or analogy that captures this?');

  form.addParagraphTextItem()
    .setTitle('Supporting files — paste links')
    .setHelpText('Screenshots, templates, recordings, articles. One per line.');

  form.addParagraphTextItem()
    .setTitle('Anything else?');

  // =================================================================
  // Wire navigation
  // =================================================================
  domainQuestion.setChoices([
    domainQuestion.createChoice('UI/UX Design', pageUIUX),
    domainQuestion.createChoice('Product Development', pageProduct),
    domainQuestion.createChoice('Engineering', pageEngineering),
    domainQuestion.createChoice('Business Development', pageBusiness),
    domainQuestion.createChoice('Marketing & Branding', pageMarketing),
    domainQuestion.createChoice('Building with AI Tools', pageAI),
    domainQuestion.createChoice('Corporate Experience', pageCorporate),
    domainQuestion.createChoice('Design Systems & Scaling', pageDesignSystems),
    domainQuestion.createChoice('Teaching & Mentoring', pageTeaching),
    domainQuestion.createChoice('Cultural Context & Local Markets', pageCultural),
    domainQuestion.createChoice('Solo Founder Survival', pageSolo),
    domainQuestion.createChoice('Content & Storytelling', pageContent),
    domainQuestion.createChoice('Lessons from Success & Failure', pageSuccessFailure),
    domainQuestion.createChoice('Founder\'s Mindset', pageFounder)
  ]);

  // Route each domain page to closing after its questions
  pageProduct.setGoToPage(pageClosing);
  pageEngineering.setGoToPage(pageClosing);
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
  pageFounder.setGoToPage(pageClosing);

  Logger.log('Combined form setup complete!');
  Logger.log('Edit URL: ' + form.getEditUrl());
  Logger.log('Published URL: ' + form.getPublishedUrl());
}
