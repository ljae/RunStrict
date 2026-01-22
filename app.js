const { useState, useEffect, useMemo } = React;

// ===== MOCK DATA =====
const generateMockData = () => {
    const crewMembers = [
        { id: 1, name: '새벽러너', avatar: '🏃', distance: 23.4, team: 'red' },
        { id: 2, name: '한강달리미', avatar: '🏃‍♀️', distance: 24.1, team: 'blue' },
        { id: 3, name: '런닝맨', avatar: '🎯', distance: 18.2, team: 'red' },
        { id: 4, name: '마라토너', avatar: '⚡', distance: 31.5, team: 'blue' },
        { id: 5, name: '조깅왕', avatar: '👟', distance: 15.7, team: 'red' },
        { id: 6, name: '페이스메이커', avatar: '🎖️', distance: 27.3, team: 'blue' },
        { id: 7, name: '러닝크루', avatar: '🌟', distance: 19.8, team: 'red' },
        { id: 8, name: '스피드스타', avatar: '💨', distance: 22.6, team: 'blue' },
        { id: 9, name: '건강러너', avatar: '💪', distance: 16.4, team: 'red' },
        { id: 10, name: '아침조깅', avatar: '🌅', distance: 20.1, team: 'blue' },
        { id: 11, name: '러닝메이트', avatar: '🤝', distance: 25.9, team: 'red' },
        { id: 12, name: '트랙스타', avatar: '🏆', distance: 29.3, team: 'blue' }
    ];

    const districts = [
        { name: '강남갑', red: 45.2, blue: 52.8, winner: 'blue', redKm: '45.2km', blueKm: '52.8km', mvp: '@런너김철수', drama: '토요일 오후 역전' },
        { name: '강남을', red: 58.3, blue: 41.7, winner: 'red', redKm: '58.3km', blueKm: '41.7km', mvp: '@새벽질주', drama: '초반부터 우세 유지' },
        { name: '강남병', red: 47.1, blue: 52.9, winner: 'blue', redKm: '47.1km', blueKm: '52.9km', mvp: '@한강러너', drama: '박빙 접전' },
        { name: '서초갑', red: 61.2, blue: 38.8, winner: 'red', redKm: '61.2km', blueKm: '38.8km', mvp: '@마라토너박', drama: '압도적 우세' },
        { name: '서초을', red: 49.8, blue: 50.2, winner: 'blue', redKm: '49.8km', blueKm: '50.2km', mvp: '@페이스메이커', drama: '0.4km 차이 극적 승리' }
    ];

    return { crewMembers, districts };
};

// ===== TEAM SELECTION COMPONENT =====
const TeamSelection = ({ onSelectTeam }) => {
    return (
        <div className="team-selection">
            <div className="bg-grid"></div>
            <div className="team-selection-header">
                <span className="team-selection-emoji">🏃</span>
                <h1 className="team-selection-title">달리기로 하나되는</h1>
                <p className="team-selection-subtitle">United Through Running</p>
                <p className="team-selection-tagline">"우리는 같은 길을 달린다"</p>
            </div>
            <div className="team-options">
                <div className="team-card red" onClick={() => onSelectTeam('red')}>
                    <div className="team-circle">🔴</div>
                    <h2 className="team-name">빨간팀</h2>
                    <p className="team-description">열정과 도전의 붉은 러너들</p>
                </div>
                <div className="team-card blue" onClick={() => onSelectTeam('blue')}>
                    <div className="team-circle">🔵</div>
                    <h2 className="team-name">파란팀</h2>
                    <p className="team-description">신뢰와 조화의 푸른 러너들</p>
                </div>
            </div>
        </div>
    );
};

// ===== MAP VIEW COMPONENT =====
const MapView = ({ userTeam }) => {
    const [hexStates, setHexStates] = useState([]);

    useEffect(() => {
        // Generate hex grid states
        const states = [];
        for (let i = 0; i < 35; i++) {
            const rand = Math.random();
            let state;
            if (rand < 0.15) {
                state = 'neutral';
            } else if (rand < 0.35) {
                state = 'red-light';
            } else if (rand < 0.5) {
                state = 'red-strong';
            } else if (rand < 0.7) {
                state = 'blue-light';
            } else if (rand < 0.9) {
                state = 'blue-strong';
            } else {
                state = 'contested';
            }
            states.push(state);
        }
        setHexStates(states);
    }, []);

    const getHexIcon = (state) => {
        if (state === 'neutral') return '';
        if (state.includes('red')) return '🔴';
        if (state.includes('blue')) return '🔵';
        if (state === 'contested') return '⚡';
        return '';
    };

    return (
        <div className="map-container fade-in">
            <div className="map-header">
                <h2 className="map-title">우리 동네 현황</h2>
                <p className="map-subtitle">실시간으로 변하는 구역 지도</p>
            </div>
            <div className="hex-map">
                <div className="hex-grid">
                    {[...Array(7)].map((_, rowIndex) => (
                        <div key={rowIndex} className="hex-row">
                            {[...Array(5)].map((_, colIndex) => {
                                const hexIndex = rowIndex * 5 + colIndex;
                                const state = hexStates[hexIndex] || 'neutral';
                                return (
                                    <div key={colIndex} className={`hex-cell ${state}`}>
                                        <div className="hex-shape">
                                            <span className="hex-icon">{getHexIcon(state)}</span>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    ))}
                </div>
            </div>
            <div className="map-legend">
                <div className="legend-item">
                    <div className="legend-hex neutral"></div>
                    <span className="legend-label">미점령</span>
                </div>
                <div className="legend-item">
                    <div className="legend-hex red"></div>
                    <span className="legend-label">빨간팀 확보</span>
                </div>
                <div className="legend-item">
                    <div className="legend-hex blue"></div>
                    <span className="legend-label">파란팀 확보</span>
                </div>
                <div className="legend-item">
                    <div className="legend-hex contested"></div>
                    <span className="legend-label">격전지 (5% 이내)</span>
                </div>
            </div>
        </div>
    );
};

// ===== RUNNING TRACKER COMPONENT =====
const RunningTracker = ({ userTeam }) => {
    const [isRunning, setIsRunning] = useState(false);
    const [isPaused, setIsPaused] = useState(false);
    const [distance, setDistance] = useState(0);
    const [duration, setDuration] = useState(0);
    const [pace, setPace] = useState(0);

    useEffect(() => {
        let interval;
        if (isRunning && !isPaused) {
            interval = setInterval(() => {
                setDuration(d => d + 1);
                // Simulate distance increase
                setDistance(dist => {
                    const newDist = dist + (Math.random() * 0.015 + 0.01);
                    return parseFloat(newDist.toFixed(2));
                });
            }, 1000);
        }
        return () => clearInterval(interval);
    }, [isRunning, isPaused]);

    useEffect(() => {
        if (duration > 0 && distance > 0) {
            const paceMin = duration / 60 / distance;
            setPace(parseFloat(paceMin.toFixed(2)));
        }
    }, [distance, duration]);

    const formatTime = (seconds) => {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    };

    const handleStart = () => {
        setIsRunning(true);
        setIsPaused(false);
    };

    const handlePause = () => {
        setIsPaused(!isPaused);
    };

    const handleStop = () => {
        setIsRunning(false);
        setIsPaused(false);
        setDistance(0);
        setDuration(0);
        setPace(0);
    };

    const hexesContributed = Math.floor(distance / 2);

    return (
        <div className="running-tracker fade-in">
            <div className="tracker-header">
                <h2 className="tracker-title">달리기 추적</h2>
                <p className="tracker-status">
                    {isRunning ? (isPaused ? '⏸️ 일시정지' : '🏃 달리는 중...') : '준비됨'}
                </p>
            </div>

            <div className="tracker-stats">
                <div className="main-stat">
                    <div className="stat-label">거리</div>
                    <div className="stat-value">
                        {distance.toFixed(2)}
                        <span className="stat-unit">km</span>
                    </div>
                </div>

                <div className="secondary-stats">
                    <div className="secondary-stat">
                        <div className="stat-label">시간</div>
                        <div className="stat-value">
                            {formatTime(duration)}
                        </div>
                    </div>
                    <div className="secondary-stat">
                        <div className="stat-label">페이스</div>
                        <div className="stat-value">
                            {pace > 0 ? pace.toFixed(1) : '0.0'}
                            <span className="stat-unit">분/km</span>
                        </div>
                    </div>
                    <div className="secondary-stat">
                        <div className="stat-label">칼로리</div>
                        <div className="stat-value">
                            {Math.floor(distance * 65)}
                            <span className="stat-unit">kcal</span>
                        </div>
                    </div>
                </div>
            </div>

            <div className="tracker-controls">
                {!isRunning ? (
                    <button className="btn btn-start" onClick={handleStart}>
                        시작하기
                    </button>
                ) : (
                    <>
                        <button className="btn btn-pause" onClick={handlePause}>
                            {isPaused ? '재개' : '일시정지'}
                        </button>
                        <button className="btn btn-stop" onClick={handleStop}>
                            종료
                        </button>
                    </>
                )}
            </div>

            <div className="territory-impact">
                <div className="impact-title">구역 기여도</div>
                <div className={`impact-value ${userTeam === 'red' ? 'red-score' : 'blue-score'}`}>
                    +{hexesContributed} 헥스
                </div>
                <p className="impact-description">
                    오늘 달리면 이 구역 뒤집을 수 있어요!
                </p>
            </div>
        </div>
    );
};

// ===== CREW COMPONENT =====
const CrewView = ({ userTeam }) => {
    const [activeTab, setActiveTab] = useState('my-crew');
    const { crewMembers } = generateMockData();

    const myCrewMembers = crewMembers.filter(m => m.team === userTeam).slice(0, 12);
    const twinCrewMembers = crewMembers.filter(m => m.team !== userTeam).slice(0, 12);

    const myCrewTotal = myCrewMembers.reduce((sum, m) => sum + m.distance, 0).toFixed(1);
    const twinCrewTotal = twinCrewMembers.reduce((sum, m) => sum + m.distance, 0).toFixed(1);

    const sortedMyCrew = [...myCrewMembers].sort((a, b) => b.distance - a.distance);
    const sortedTwinCrew = [...twinCrewMembers].sort((a, b) => b.distance - a.distance);

    return (
        <div className="crew-container fade-in">
            <div className="crew-header">
                <h2 className="crew-title">크루 시스템</h2>
            </div>

            <div className="crew-tabs">
                <div
                    className={`crew-tab ${activeTab === 'my-crew' ? 'active' : ''}`}
                    onClick={() => setActiveTab('my-crew')}
                >
                    내 크루
                </div>
                <div
                    className={`crew-tab ${activeTab === 'twin-crew' ? 'active' : ''}`}
                    onClick={() => setActiveTab('twin-crew')}
                >
                    트윈 크루
                </div>
            </div>

            {activeTab === 'my-crew' && (
                <div className="crew-card slide-in">
                    <div className="crew-card-header">
                        <div className="crew-name-section">
                            <div className={`crew-badge ${userTeam}`}>
                                {userTeam === 'red' ? '🔴' : '🔵'}
                            </div>
                            <h3 className="crew-name">{userTeam === 'red' ? '새벽질주단' : '한강러너스'}</h3>
                        </div>
                        <div className="crew-stats-summary">
                            <div className="crew-stat-line">
                                이번 주 누적: <span className="crew-stat-value">{myCrewTotal}km</span>
                            </div>
                            <div className="crew-stat-line">
                                점령 헥스: <span className="crew-stat-value">7개</span>
                            </div>
                        </div>
                    </div>
                    <div className="crew-members-grid">
                        {sortedMyCrew.map((member, index) => (
                            <div key={member.id} className="member-card">
                                <div className="member-avatar">{member.avatar}</div>
                                <div className="member-info">
                                    <div className="member-name">{member.name}</div>
                                    <div className="member-distance">{member.distance}km</div>
                                </div>
                                <div className="member-rank">
                                    {index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : ''}
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {activeTab === 'twin-crew' && (
                <>
                    <div className="twin-rivalry slide-in">
                        <div className="rivalry-header">
                            <div className="rivalry-title">⚔️ 이번 주 더비</div>
                        </div>
                        <div className="rivalry-vs">
                            <div className="rivalry-team">
                                <div className={`rivalry-team-name ${userTeam === 'red' ? 'red-score' : 'blue-score'}`}>
                                    {userTeam === 'red' ? '새벽질주단' : '한강러너스'}
                                </div>
                                <div className={`rivalry-team-score ${userTeam === 'red' ? 'red-score' : 'blue-score'}`}>
                                    {myCrewTotal}km
                                </div>
                            </div>
                            <div className="rivalry-divider">VS</div>
                            <div className="rivalry-team">
                                <div className={`rivalry-team-name ${userTeam === 'red' ? 'blue-score' : 'red-score'}`}>
                                    {userTeam === 'red' ? '한강러너스' : '새벽질주단'}
                                </div>
                                <div className={`rivalry-team-score ${userTeam === 'red' ? 'blue-score' : 'red-score'}`}>
                                    {twinCrewTotal}km
                                </div>
                            </div>
                        </div>
                        <div className="rivalry-record">
                            <div className="rivalry-record-title">트윈 전적</div>
                            <div className="rivalry-record-value">
                                {userTeam === 'red' ? '🔴 4승 - 5승 🔵' : '🔵 5승 - 4승 🔴'}
                            </div>
                        </div>
                        <div className="rivalry-message">
                            <div className="rivalry-message-label">💬 상대 크루장 메시지:</div>
                            <div className="rivalry-message-text">"이번 주는 안 지겠습니다 ㅎㅎ"</div>
                        </div>
                    </div>

                    <div className="crew-card slide-in">
                        <div className="crew-card-header">
                            <div className="crew-name-section">
                                <div className={`crew-badge ${userTeam === 'red' ? 'blue' : 'red'}`}>
                                    {userTeam === 'red' ? '🔵' : '🔴'}
                                </div>
                                <h3 className="crew-name">{userTeam === 'red' ? '한강러너스' : '새벽질주단'}</h3>
                            </div>
                            <div className="crew-stats-summary">
                                <div className="crew-stat-line">
                                    이번 주 누적: <span className="crew-stat-value">{twinCrewTotal}km</span>
                                </div>
                                <div className="crew-stat-line">
                                    점령 헥스: <span className="crew-stat-value">9개</span>
                                </div>
                            </div>
                        </div>
                        <div className="crew-members-grid">
                            {sortedTwinCrew.map((member, index) => (
                                <div key={member.id} className="member-card">
                                    <div className="member-avatar">{member.avatar}</div>
                                    <div className="member-info">
                                        <div className="member-name">{member.name}</div>
                                        <div className="member-distance">{member.distance}km</div>
                                    </div>
                                    <div className="member-rank">
                                        {index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : ''}
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </>
            )}
        </div>
    );
};

// ===== RESULTS COMPONENT (Electoral Style) =====
const ResultsView = ({ userTeam }) => {
    const { districts } = generateMockData();

    const redSeats = districts.filter(d => d.winner === 'red').length;
    const blueSeats = districts.filter(d => d.winner === 'blue').length;
    const totalRedKm = districts.reduce((sum, d) => sum + parseFloat(d.redKm), 0).toFixed(1);
    const totalBlueKm = districts.reduce((sum, d) => sum + parseFloat(d.blueKm), 0).toFixed(1);

    return (
        <div className="results-container fade-in">
            <div className="results-breaking">
                <div className="results-breaking-text">📊 속보: 주간 집계 완료</div>
            </div>

            <div className="results-header">
                <h2 className="results-title">제47대 [강남구] 주간 결산</h2>
                <p className="results-meta">2026년 1월 10일 집계 완료</p>
            </div>

            <div className="results-scoreboard">
                <div className="scoreboard-team red">
                    <div className="scoreboard-header">
                        <span className="scoreboard-icon">🔴</span>
                        <h3 className="scoreboard-team-name">빨간팀</h3>
                    </div>
                    <div className="scoreboard-stats">
                        <div className="scoreboard-stat">
                            <span className="scoreboard-stat-label">총 거리</span>
                            <span className="scoreboard-stat-value red-score">{totalRedKm}km</span>
                        </div>
                        <div className="scoreboard-stat">
                            <span className="scoreboard-stat-label">평균 페이스</span>
                            <span className="scoreboard-stat-value">5:42/km</span>
                        </div>
                        <div className="scoreboard-stat">
                            <span className="scoreboard-stat-label">활성 러너</span>
                            <span className="scoreboard-stat-value">142명</span>
                        </div>
                    </div>
                    <div className="scoreboard-seats">
                        <div className="seats-label">획득 선거구</div>
                        <div className="seats-value red-score">{redSeats}석</div>
                    </div>
                </div>

                <div className="scoreboard-team blue">
                    <div className="scoreboard-header">
                        <span className="scoreboard-icon">🔵</span>
                        <h3 className="scoreboard-team-name">파란팀</h3>
                    </div>
                    <div className="scoreboard-stats">
                        <div className="scoreboard-stat">
                            <span className="scoreboard-stat-label">총 거리</span>
                            <span className="scoreboard-stat-value blue-score">{totalBlueKm}km</span>
                        </div>
                        <div className="scoreboard-stat">
                            <span className="scoreboard-stat-label">평균 페이스</span>
                            <span className="scoreboard-stat-value">5:38/km</span>
                        </div>
                        <div className="scoreboard-stat">
                            <span className="scoreboard-stat-label">활성 러너</span>
                            <span className="scoreboard-stat-value">158명</span>
                        </div>
                    </div>
                    <div className="scoreboard-seats">
                        <div className="seats-label">획득 선거구</div>
                        <div className="seats-value blue-score">{blueSeats}석</div>
                    </div>
                </div>
            </div>

            <div className="results-districts">
                <h3 className="districts-title">선거구별 결과</h3>
                <div className="district-list">
                    {districts.map((district, index) => (
                        <div key={index} className="district-item slide-in" style={{animationDelay: `${index * 0.1}s`}}>
                            <div className="district-header">
                                <span className="district-name">{district.name}</span>
                                <span className="district-winner">
                                    {district.winner === 'red' ? '🔴' : '🔵'}
                                </span>
                            </div>
                            <div className="district-bar">
                                <div
                                    className="district-bar-fill red"
                                    style={{width: `${district.red}%`}}
                                >
                                    {district.red > 15 && `${district.red}%`}
                                </div>
                                <div
                                    className="district-bar-fill blue"
                                    style={{width: `${district.blue}%`}}
                                >
                                    {district.blue > 15 && `${district.blue}%`}
                                </div>
                            </div>
                            <div className="district-meta">
                                <span>🔴 {district.redKm} vs 🔵 {district.blueKm}</span>
                                <span>{district.drama}</span>
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            <div className="results-highlights">
                <h3 className="highlights-title">주간 하이라이트</h3>
                <div className="highlight-item">
                    <div className="highlight-label">MVP</div>
                    <div className="highlight-value">@런너김철수 (12.4km 기여)</div>
                </div>
                <div className="highlight-item">
                    <div className="highlight-label">역전 드라마</div>
                    <div className="highlight-value">강남을 (토요일 오후 역전)</div>
                </div>
                <div className="highlight-item">
                    <div className="highlight-label">격전지</div>
                    <div className="highlight-value">서초을 (0.4km 차이)</div>
                </div>
            </div>
        </div>
    );
};

// ===== LEADERBOARD COMPONENT =====
const Leaderboard = ({ userTeam }) => {
    const { crewMembers } = generateMockData();
    const [filter, setFilter] = useState('all');

    const filteredMembers = useMemo(() => {
        let members = [...crewMembers];
        if (filter === 'my-team') {
            members = members.filter(m => m.team === userTeam);
        } else if (filter === 'other-team') {
            members = members.filter(m => m.team !== userTeam);
        }
        return members.sort((a, b) => b.distance - a.distance);
    }, [filter, userTeam, crewMembers]);

    return (
        <div className="leaderboard-container fade-in">
            <div className="leaderboard-header">
                <h2 className="leaderboard-title">리더보드</h2>
                <p className="leaderboard-period">이번 주 랭킹</p>
            </div>

            <div className="leaderboard-filters">
                <button
                    className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
                    onClick={() => setFilter('all')}
                >
                    전체
                </button>
                <button
                    className={`filter-btn ${filter === 'my-team' ? 'active' : ''}`}
                    onClick={() => setFilter('my-team')}
                >
                    내 팀
                </button>
                <button
                    className={`filter-btn ${filter === 'other-team' ? 'active' : ''}`}
                    onClick={() => setFilter('other-team')}
                >
                    상대 팀
                </button>
            </div>

            <div className="leaderboard-list">
                {filteredMembers.map((member, index) => (
                    <div
                        key={member.id}
                        className={`leaderboard-item ${index === 0 ? 'top-1' : index === 1 ? 'top-2' : index === 2 ? 'top-3' : ''}`}
                    >
                        <div className="leaderboard-rank">#{index + 1}</div>
                        <div className={`leaderboard-avatar ${member.team}`}>
                            {member.avatar}
                        </div>
                        <div className="leaderboard-info">
                            <div className="leaderboard-name">{member.name}</div>
                            <div className="leaderboard-crew">
                                {member.team === 'red' ? '🔴 새벽질주단' : '🔵 한강러너스'}
                            </div>
                        </div>
                        <div className="leaderboard-distance">
                            {member.distance}
                            <span className="leaderboard-unit">km</span>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};

// ===== MAIN APP COMPONENT =====
const App = () => {
    const [userTeam, setUserTeam] = useState(null);
    const [currentView, setCurrentView] = useState('map');
    const [territoryBalance, setTerritoryBalance] = useState({ red: 48, blue: 52 });

    const handleSelectTeam = (team) => {
        setUserTeam(team);
    };

    const renderView = () => {
        switch(currentView) {
            case 'map':
                return <MapView userTeam={userTeam} />;
            case 'run':
                return <RunningTracker userTeam={userTeam} />;
            case 'crew':
                return <CrewView userTeam={userTeam} />;
            case 'results':
                return <ResultsView userTeam={userTeam} />;
            case 'leaderboard':
                return <Leaderboard userTeam={userTeam} />;
            default:
                return <MapView userTeam={userTeam} />;
        }
    };

    if (!userTeam) {
        return <TeamSelection onSelectTeam={handleSelectTeam} />;
    }

    return (
        <div className="main-app">
            <div className="bg-grid"></div>

            {/* Top Bar */}
            <div className="top-bar">
                <div className="top-bar-left">
                    <div className="app-logo">🏃 달리기로 하나되는</div>
                    <div className="territory-balance">
                        <span className="balance-percentage red-score">{territoryBalance.red}%</span>
                        <div className="balance-bar">
                            <div className="balance-fill">
                                <div className="balance-red" style={{width: `${territoryBalance.red}%`}}></div>
                                <div className="balance-blue" style={{width: `${territoryBalance.blue}%`}}></div>
                            </div>
                        </div>
                        <span className="balance-percentage blue-score">{territoryBalance.blue}%</span>
                    </div>
                </div>
                <div className="top-bar-right">
                    <div className="notification-bell">
                        🔔
                        <div className="notification-badge">3</div>
                    </div>
                    <div className="user-info">
                        <div className={`user-avatar ${userTeam}`}>
                            {userTeam === 'red' ? '🔴' : '🔵'}
                        </div>
                        <span>러너</span>
                    </div>
                </div>
            </div>

            {/* Main Content */}
            {renderView()}

            {/* Bottom Navigation */}
            <div className="bottom-nav">
                <div
                    className={`nav-item ${currentView === 'map' ? `active ${userTeam}` : ''}`}
                    onClick={() => setCurrentView('map')}
                >
                    <div className="nav-icon">🗺️</div>
                    <div className="nav-label">지도</div>
                </div>
                <div
                    className={`nav-item ${currentView === 'run' ? `active ${userTeam}` : ''}`}
                    onClick={() => setCurrentView('run')}
                >
                    <div className="nav-icon">🏃</div>
                    <div className="nav-label">달리기</div>
                </div>
                <div
                    className={`nav-item ${currentView === 'crew' ? `active ${userTeam}` : ''}`}
                    onClick={() => setCurrentView('crew')}
                >
                    <div className="nav-icon">👥</div>
                    <div className="nav-label">크루</div>
                </div>
                <div
                    className={`nav-item ${currentView === 'results' ? `active ${userTeam}` : ''}`}
                    onClick={() => setCurrentView('results')}
                >
                    <div className="nav-icon">📊</div>
                    <div className="nav-label">결과</div>
                </div>
                <div
                    className={`nav-item ${currentView === 'leaderboard' ? `active ${userTeam}` : ''}`}
                    onClick={() => setCurrentView('leaderboard')}
                >
                    <div className="nav-icon">🏆</div>
                    <div className="nav-label">순위</div>
                </div>
            </div>
        </div>
    );
};

// Render the app
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
