import Foundation

enum ConsumerAppContent {
  struct Copy { var title: String; var detail: String }

  /// Ordered against the classified SaaS-specific source shape: role, category,
  /// urgency, impact, and era remain identical while every player-facing line is
  /// authored for a direct-to-consumer product.
  static let taskCopy: [Copy] = [
    .init(title: "Instrument the First Session", detail: "Capture the three taps that predict whether a new user returns tomorrow."),
    .init(title: "Cut Cold-Start Friction", detail: "Remove the loading pause that loses users before the home screen appears."),
    .init(title: "Build the Daily Loop", detail: "Give returning users a reason to open the app before their routine moves on."),
    .init(title: "Ship the Share Card", detail: "Make a completed moment worth posting without turning it into an ad."),
    .init(title: "Harden Account Recovery", detail: "Let users regain their history after a lost phone without exposing private data."),
    .init(title: "Fix Purchase Restoration", detail: "Recover paid access after an App Store receipt goes missing."),
    .init(title: "Tune Notification Timing", detail: "Send one useful reminder when a user is likely to act, not five they will mute."),
    .init(title: "Protect the Creator Feed", detail: "Stop a ranking bug from hiding the work that makes the community feel alive."),
    .init(title: "Measure Day-One Retention", detail: "Find the first-session action shared by people who come back tomorrow."),
    .init(title: "Study Review Sentiment", detail: "Separate a real product complaint from a one-star pile-on before changing the roadmap."),
    .init(title: "Test the Freemium Gate", detail: "Learn which limit creates paid intent without making the free app feel broken."),
    .init(title: "Audit Ad Targeting", detail: "Verify that the network’s audience assumptions do not expose users or waste spend."),
    .init(title: "Trace Referral Fraud", detail: "Find the invite loop that is buying fake growth instead of real friends."),
    .init(title: "Model Seasonal Demand", detail: "Prepare the service for the week users predictably arrive all at once."),
    .init(title: "Validate Family Sharing", detail: "Check that shared subscriptions deliver value without creating accidental free riders."),
    .init(title: "Investigate Ranking Drop", detail: "Identify whether a store algorithm change or weaker reviews pushed discovery down."),
    .init(title: "Publish Privacy Nutrition", detail: "Explain data collection in language a cautious parent can actually understand."),
    .init(title: "Recruit Beta Creators", detail: "Give small creators early access and a reason to make honest launch content."),
    .init(title: "Pitch a Feature Story", detail: "Turn one surprising user behavior into an editorial angle that earns discovery."),
    .init(title: "Launch the Win-Back Series", detail: "Invite dormant users back with a new reason to care, not a generic discount."),
    .init(title: "Negotiate Ad Inventory", detail: "Trade placement certainty for a rate that leaves room for product investment."),
    .init(title: "Respond to Store Rejection", detail: "Address the policy issue clearly before the launch window closes."),
    .init(title: "Run an Influencer Trial", detail: "Pay for a small creator cohort before committing the brand to one loud voice."),
    .init(title: "Convert the Power Users", detail: "Offer the most active free users a paid upgrade that matches how they already use the app."),
    .init(title: "Refresh Store Screenshots", detail: "Show the current product truth before old images depress conversion."),
    .init(title: "Repair the Ratings Slide", detail: "Answer a cluster of reviews with a fix and a respectful public reply."),
    .init(title: "Build Consent Operations", detail: "Keep notification, tracking, and parental permissions coherent as the audience grows."),
    .init(title: "Reconcile Subscription Support", detail: "Connect purchase complaints to the account states that caused them."),
    .init(title: "Contain a Data Deletion Error", detail: "Restore the promised privacy path before a support thread becomes a public warning."),
    .init(title: "Create the App Store Event", detail: "Use the platform’s editorial slot to make a focused release discoverable."),
    .init(title: "Ship Offline Downloading", detail: "Keep the core experience useful when a commute or flight removes the connection."),
    .init(title: "Refactor the Feed Cache", detail: "Stop stale recommendations from making frequent users feel the app has stopped learning."),
    .init(title: "Build Crash Triage", detail: "Turn device-specific failures into a fix order before reviews identify them first."),
    .init(title: "Instrument Paywall Fatigue", detail: "Measure when repeated upgrade prompts turn intent into resentment."),
    .init(title: "Secure Child Accounts", detail: "Close the age-verification gap before a platform audit finds it."),
    .init(title: "Map Seven-Day Churn", detail: "Learn which habit breaks cause a new subscriber to disappear within a week."),
    .init(title: "Validate Creator Onboarding", detail: "Watch a first-time creator publish from a blank account and remove the confusing step."),
    .init(title: "Audit Trial Messaging", detail: "Make renewal language clear before a surprise charge becomes a ratings crisis."),
    .init(title: "Forecast Acquisition Spend", detail: "Model which paid channels still work after attribution becomes less certain."),
    .init(title: "Test Recommendation Bias", detail: "Check whether the ranking loop quietly excludes a meaningful group of users."),
    .init(title: "Publish a Retention Case Study", detail: "Show prospective users how a real person made the app part of their week."),
    .init(title: "Host a Live Challenge", detail: "Create a time-bound community moment that gives friends a reason to invite each other."),
    .init(title: "Settle a Platform Bundle", detail: "Trade a lower share of subscription revenue for placement inside a larger service."),
    .init(title: "Recover a Botched Update", detail: "Own the broken release and guide affected users back to a working version."),
    .init(title: "Run a Back-to-School Push", detail: "Meet the seasonal audience with a use case they can immediately share."),
    .init(title: "Pitch the Creator Newsletter", detail: "Earn a trusted recommendation from the people users already follow."),
    .init(title: "Renegotiate Push Infrastructure", detail: "Cut delivery costs without making reminders arrive after the moment matters."),
    .init(title: "Document Store Escalations", detail: "Give support a repeatable path when a platform policy blocks a release."),
    .init(title: "Schedule a Creator Break", detail: "Protect the founder from becoming the always-on voice of the community."),
    .init(title: "Reconcile Moderation Promises", detail: "Align public safety claims with the tools moderators actually have."),
    .init(title: "Shard the Activity Feed", detail: "Split the busiest social stream before a viral day turns refreshes into churn."),
    .init(title: "Build a Cross-Device Session", detail: "Let a user continue a habit across phone, tablet, and web without losing progress."),
    .init(title: "Ship a Safe Rollback", detail: "Make an app update reversible before a global release traps users in a bad build."),
    .init(title: "Support Managed Devices", detail: "Meet the privacy controls schools and families require before recommending the app."),
    .init(title: "Cut Media Delivery Costs", detail: "Reduce the bill for each streamed minute without making the experience look cheap."),
    .init(title: "Harden Abuse Limits", detail: "Stop scripted signups from exhausting the service real users depend on."),
    .init(title: "Build the Creator Sandbox", detail: "Let partners test publishing tools without exposing live followers to mistakes."),
    .init(title: "Automate Device Regression", detail: "Catch a broken gesture on older phones before it becomes thousands of one-star reviews."),
    .init(title: "Migrate Regional Delivery", detail: "Keep a local outage from making the app disappear in an entire market."),
    .init(title: "Open the Creator Toolkit", detail: "Give trusted creators tools to build companion experiences around the app."),
    .init(title: "Run a New-Genre Study", detail: "Find the next audience cluster before competitors teach it a different habit."),
    .init(title: "Quantify Notification Risk", detail: "Measure how much one bad campaign could push users to disable the channel forever."),
    .init(title: "Study International Retention", detail: "Learn which local behaviors survive after the app crosses a language boundary."),
    .init(title: "Verify Youth-Safety Exposure", detail: "Know which community rules must withstand regulator and parent scrutiny."),
    .init(title: "Segment Usage Rhythms", detail: "Separate daily regulars from seasonal visitors so each receives a useful experience."),
    .init(title: "Audit Recommendation Calibration", detail: "Find where confident suggestions are less helpful than the app claims."),
    .init(title: "Study Subscriber Cohorts", detail: "Compare the people who renew after week four with those who cancel on day seven."),
    .init(title: "Map Media Acquisition Buyers", detail: "Understand which platforms value the audience, data, and habit you have built."),
    .init(title: "Benchmark Community Support", detail: "Test whether agent replies feel timely and human enough for frustrated users."),
    .init(title: "Forecast Community Manager Fatigue", detail: "Predict where constant creator demand will burn out the people keeping the app safe."),
    .init(title: "Land a Featured Collection", detail: "Convert one high-visibility placement into permission to win the next audience."),
    .init(title: "Publish the Safety Ledger", detail: "Make moderation outcomes visible before rumors define the community’s standards."),
    .init(title: "Lead a Creator Keynote", detail: "Set the product’s creative agenda before a rival platform names it first."),
    .init(title: "Launch in a New Storefront", detail: "Open a regional distribution channel where the app already has organic demand."),
    .init(title: "Answer a Viral Callout", detail: "Respond with receipts before a misleading clip becomes the product’s identity."),
    .init(title: "Build an Ambassador Program", detail: "Reward credible users for teaching newcomers without buying their praise."),
    .init(title: "Convert the Trial Cohort", detail: "Turn users who found value this week into subscribers before the habit fades."),
    .init(title: "Rebrand for Mainstream", detail: "Signal safety and polish to people who will not adopt an insider product."),
    .init(title: "Win a Mobile Design Award", detail: "Earn third-party recognition that lowers the trust barrier for a first download."),
    .init(title: "Reactivate Lapsed Subscribers", detail: "Bring back former paying users with the specific improvement they left for."),
    .init(title: "Renegotiate App Platform Fees", detail: "Protect margin before a store policy change makes the current economics permanent.")
  ]

  static func tasks(from source: [SoloTask]) -> [SoloTask] {
    return zip(source, taskCopy.prefix(source.count)).map { source, copy in
      var task = source; task.title = copy.title; task.detail = copy.detail; task.productTypes = [.consumerApp]; return task
    }
  }

  static func dilemmas(from source: [FounderDilemma]) -> [FounderDilemma] {
    let setups = [
      "A creator wants one more sharing feature, but the first-session loop is still fragile.",
      "Brio wants to promise an algorithm that feels magical before retention data supports it.",
      "The launch build can gain polish tonight, but the founder has already been answering creator messages for days.",
      "A popular creator will promote the app if their audience gets an exclusive feature nobody else can use.",
      "A subscriber says a renewal notification arrived too late and wants the charge reversed publicly.",
      "A growth partner offers cheap installs if the app adds a more aggressive interstitial ad.",
      "A platform outage is making new users think the app itself has failed on launch day.",
      "A reporter asks whether push notifications are designed to help users or simply maximize opens.",
      "A rival copied the creator challenge that made your launch visible this week.",
      "An investor offers runway but wants the app to optimize ad yield ahead of user wellbeing.",
      "The community is growing quickly, and users want a named human to own safety escalations.",
      "A larger consumer platform offers to acquire the app and fold its habit loop into a portfolio."
    ]
    return zip(source, setups).map { dilemma, setup in
      var authored = dilemma
      authored.id = "consumerApp-\(dilemma.id)"
      authored.title = "Consumer App: \(dilemma.title)"
      authored.setup = setup
      authored.productTypes = [.consumerApp]
      authored.choices = dilemma.choices.enumerated().map { index, choice in
        DilemmaChoice(id: "consumer-\(choice.id)", title: ["Protect the Habit", "Take the Reach", "Run a Limited Test"][index], detail: ["Prioritize a durable user relationship.", "Trade some certainty for immediate attention.", "Learn with a bounded commitment before scaling."][index], consequencePreview: ["Trust and focus", "Momentum with risk", "Balanced evidence and cost"][index], effects: choice.effects, relationshipDeltas: choice.relationshipDeltas)
      }
      return authored
    }
  }
}
