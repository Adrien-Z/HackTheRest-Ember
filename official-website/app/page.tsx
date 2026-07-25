export default function Home() {
  return (
    <main>
      <nav className="nav" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="EMBER home">
          <img src="/assets/ember-app-icon.png" alt="" />
          <span>EMBER</span>
        </a>
        <div className="navLinks">
          <a href="#how-it-works">How it works</a>
          <a href="#science">Science</a>
          <a href="#box-space">Box Space</a>
        </div>
        <a className="navCta" href="#experience">Meet Ember <span>↘</span></a>
      </nav>

      <section className="hero" id="top">
        <div className="aurora auroraOne" />
        <div className="aurora auroraTwo" />
        <div className="heroCopy">
          <p className="eyebrow"><span /> A personal rest coach for iPhone</p>
          <h1>Sleep is a skill.<br /><em>We coach it.</em></h1>
          <p className="heroLead">
            EMBER turns your sleep, calendar, and environment into one clear,
            personalized plan for tonight.
          </p>
          <div className="heroActions">
            <a className="button buttonPrimary" href="#how-it-works">
              See how it works <span>↓</span>
            </a>
            <a className="button buttonQuiet" href="#science">
              Explore the science
            </a>
          </div>
          <div className="trustRow" aria-label="Core product principles">
            <span><b></b> Apple Health</span>
            <span><i /> Private by design</span>
            <span><i /> Adapts nightly</span>
          </div>
        </div>

        <div className="heroVisual" aria-label="EMBER app preview">
          <div className="heroGlow" />
          <img className="heroMascot" src="/assets/sleepy-blue.png" alt="The sleepy Blue Box character" />
          <div className="phone">
            <div className="phoneTop"><span>9:41</span><i /></div>
            <div className="phoneHeader">
              <div><small>GOOD EVENING</small><strong>Ready for tonight?</strong></div>
              <span className="miniAvatar">E</span>
            </div>
            <div className="scoreCard">
              <div className="scoreTitle"><span>Sleep score</span><small>LAST NIGHT</small></div>
              <div className="scoreMain"><b>82</b><span>Great recovery<br /><small>+7 from average</small></span></div>
              <div className="chartBars" aria-hidden="true">
                {[42, 58, 50, 72, 64, 88, 82].map((height, index) => (
                  <i key={index} style={{ height: `${height}%` }} />
                ))}
              </div>
            </div>
            <div className="planCard">
              <div className="planHeading"><span>☾</span><strong>Tonight&apos;s plan</strong><small>ADAPTED</small></div>
              <div className="planTimes">
                <span><b>9:45</b><small>start warming</small></span>
                <span><b>10:30</b><small>lights out</small></span>
                <span><b>6:45</b><small>wake</small></span>
              </div>
              <p>Early stand-up tomorrow. Your plan moved 15 min earlier.</p>
            </div>
            <div className="coachPill"><span>✦</span><b>Ask Rest Coach</b><i>→</i></div>
            <div className="phoneTabs"><span className="active">⌂<small>Tonight</small></span><span>◴<small>Agenda</small></span><span>◇<small>Rest Lab</small></span></div>
          </div>
          <div className="floatBadge badgeCalendar"><span>8:30</span><b>Early meeting</b><small>Plan adjusted</small></div>
          <div className="floatBadge badgeWind"><span>21°</span><b>Cool night</b><small>Ideal for sleep</small></div>
        </div>
      </section>

      <section className="statement" id="experience">
        <p>THE DIFFERENCE</p>
        <h2>A tracker tells you about last night.<br />EMBER tells you what to do <em>tonight.</em></h2>
      </section>

      <section className="featureSection" id="how-it-works">
        <div className="sectionIntro">
          <p className="eyebrow"><span /> Built around your real life</p>
          <h2>One plan. Four signals.<br />Zero guesswork.</h2>
          <p>Every recommendation has a reason. Ember quietly brings together the signals that shape your night, then gives you the next useful step.</p>
        </div>
        <div className="bento">
          <article className="featureCard featureLarge calendarCard">
            <div className="cardNumber">01</div>
            <div className="miniCalendar" aria-hidden="true">
              <div className="calendarHead"><span>Tomorrow</span><b>JUL 26</b></div>
              <div className="event"><time>8:30</time><i /><span><b>Team stand-up</b><small>Video call</small></span></div>
              <div className="event"><time>10:00</time><i /><span><b>Design review</b><small>Studio</small></span></div>
              <div className="adjustment"><span>Plan updated</span><b>Wake at 6:45</b></div>
            </div>
            <div className="cardCopy">
              <p>Calendar-aware</p>
              <h3>Your day already knows when your night should start.</h3>
              <span>Early flight? Late dinner? Ember protects your wake time and adapts the plan around it.</span>
            </div>
          </article>

          <article className="featureCard thermalCard">
            <div className="cardNumber">02</div>
            <div className="thermalDial" aria-hidden="true"><span>40</span><b>min before bed</b><i /></div>
            <div className="cardCopy">
              <p>Thermal wind-down</p>
              <h3>Warm up to cool down.</h3>
              <span>Times a warm ritual to support your body&apos;s natural temperature drop.</span>
            </div>
          </article>

          <article className="featureCard coachCard">
            <div className="cardNumber">03</div>
            <div className="coachChat" aria-hidden="true">
              <p>I have to be up at 5. What should I change?</p>
              <div><span>✦</span><p>Start warming at 8:50 and aim for lights out by 9:35. I&apos;ve protected your morning prep time.</p></div>
            </div>
            <div className="cardCopy">
              <p>Rest Coach</p>
              <h3>Answers grounded in your plan.</h3>
              <span>Ask what changed, why it matters, or what to do when the night goes sideways.</span>
            </div>
          </article>

          <article className="featureCard featureWide healthCard">
            <div className="cardNumber">04</div>
            <div className="healthVisual" aria-hidden="true">
              <div><small>SLEEP EFFICIENCY</small><b>91%</b><span>↑ 4% this week</span></div>
              <div className="healthLine"><i /><i /><i /><i /><i /><i /><i /></div>
            </div>
            <div className="cardCopy">
              <p>Apple Health</p>
              <h3>Learns from your real sleep — without asking you to log it.</h3>
              <span>Your overnight data stays on your device. Ember reads what it needs and never writes to Health.</span>
            </div>
          </article>
        </div>
      </section>

      <section className="nightPlan">
        <div className="nightTexture" />
        <div className="nightCopy">
          <p className="eyebrow"><span /> Tonight, made simple</p>
          <h2>A plan you can follow half-asleep.</h2>
          <p>Ember turns the science into a small sequence of well-timed actions. No spreadsheet. No sleep math at 10 p.m.</p>
          <div className="timeline">
            <div><b>9:45</b><span><strong>Start warming</strong><small>A short foot bath or warm towel begins the thermal cue.</small></span></div>
            <div><b>10:20</b><span><strong>Dim and downshift</strong><small>Ember clears the last ten minutes for a quieter landing.</small></span></div>
            <div><b>10:30</b><span><strong>Lights out</strong><small>Your sleep window starts. The alarm is already set.</small></span></div>
          </div>
        </div>
        <div className="nightVisual" aria-hidden="true">
          <div className="orb"><span>10:30</span><small>LIGHTS OUT</small></div>
          <img src="/assets/rest-sheet.png" alt="" />
        </div>
      </section>

      <section className="science" id="science">
        <div className="scienceHeader">
          <p className="eyebrow"><span /> The Rest Lab</p>
          <h2>Evidence in.<br />Better nights out.</h2>
          <p>Ember is built around two proven levers for better rest: steady sleep timing and a well-timed drop in core body temperature.</p>
        </div>
        <div className="scienceGrid">
          <article>
            <span className="scienceIndex">A</span>
            <p>PROTOCOL 01</p>
            <h3>Sleep Window Training</h3>
            <p>A practical, adaptive take on CBT-I sleep efficiency. Ember starts with a realistic window and widens it as your sleep becomes more solid.</p>
            <div className="efficiency"><span><b>82%</b><small>WEEK 1</small></span><i>→</i><span><b>91%</b><small>WEEK 4</small></span></div>
          </article>
          <article>
            <span className="scienceIndex">B</span>
            <p>PROTOCOL 02</p>
            <h3>Thermal Wind-Down</h3>
            <p>Strategic warming helps your hands and feet release heat, supporting the natural core-temperature drop that precedes sleep.</p>
            <div className="tempCurve"><i /><span>WARM</span><span>SLEEP</span></div>
          </article>
        </div>
        <p className="scienceNote">EMBER is a wellness tool, not a medical device. It does not diagnose or treat sleep disorders.</p>
      </section>

      <section className="boxSpace" id="box-space">
        <div className="boxCopy">
          <p className="eyebrow"><span /> Meet Blue Box</p>
          <h2>Better habits deserve a little joy.</h2>
          <p>Keep your plan, build a streak, and unlock new Blue Box skins in Box Space. Progress feels warmer when it has a personality.</p>
          <div className="skinLabels"><span>10+ skins</span><span>Weekly rewards</span><span>Friend pods</span></div>
        </div>
        <div className="skinStage" aria-label="A selection of collectible Blue Box skins">
          <div className="skin skinOne"><img src="/assets/cozy-blue.png" alt="Cozy Blue Box skin" /></div>
          <div className="skin skinTwo"><img src="/assets/happy-blue.png" alt="Happy Blue Box skin" /></div>
          <div className="skin skinThree"><img src="/assets/dream-blue.png" alt="Dream Blue Box skin" /></div>
          <div className="skin skinFour"><img src="/assets/moon-blue.png" alt="Moon Blue Box skin" /></div>
        </div>
      </section>

      <section className="privacy">
        <div className="privacyMark"><span>⌾</span></div>
        <div>
          <p>PRIVATE BY DESIGN</p>
          <h2>Your nights are yours.</h2>
        </div>
        <p>Sleep and recovery data stays on your iPhone. Ember uses Apple Health with read-only access and never uploads your nights.</p>
      </section>

      <section className="finalCta">
        <div className="finalGlow" />
        <img src="/assets/ember-app-icon.png" alt="Blue Box, the EMBER app icon" />
        <p>COMING TO IPHONE</p>
        <h2>Your best nights<br />are learnable.</h2>
        <a className="button buttonPrimary" href="#top">Meet EMBER <span>↑</span></a>
      </section>

      <footer>
        <a className="brand footerBrand" href="#top">
          <img src="/assets/ember-app-icon.png" alt="" />
          <span>EMBER</span>
        </a>
        <p>Sleep is a skill. We coach it.</p>
        <p>© 2026 EMBER · Built for iPhone</p>
      </footer>
    </main>
  );
}
