import React, { PropTypes } from 'react';
import { connect } from 'react-redux';
import * as GrooveActions from '../actionCreators';
import { bindActionCreators } from 'redux';

import Player     from '../components/Player';
import Sidebar    from '../components/Sidebar';
import Settings   from '../components/Settings';
import Playlist   from '../components/Playlist';
import Library    from '../components/Library';
import TrackList    from '../components/TrackList';

class GrooveApp extends React.Component {

  render() {
    const {
        actions,
        view,
        playing,
        currentTrack,
        grooveSocket,
        dispatch,
        library,
        queue,
        startTime,
        pausedDuration
      } = this.props;

    let currentId = currentTrack ? currentTrack.index : '';
    let mainView;
    switch(view) {
      case 'QUEUE':
        const {requestPlayTrack} = GrooveActions;
        mainView = <TrackList tracks={queue}
                    keyAttr={"index"}
                    currentKey={currentId}
                    onClickHandler={(track) => requestPlayTrack(track.index)}/>;
        break;
      case 'SETTINGS':
        var settings = {
          'hwPlayback': true,
          'hwVolume': 1
        };
        mainView = <Settings settings={settings}/>;
        break;
      case 'PLAYLIST':
        let playlist = '';
        mainView = <Playlist playlist={playlist}/>;
        break;
      case 'LIBRARY':
        mainView = <Library library={library} dispatch={dispatch} />;
        break;
      default:
        mainView = '';
    }

    return (
      <div>
        <Player
          actions={actions}
          playing={playing}
          startTime={startTime}
          pausedDuration={pausedDuration}
          track={currentTrack} />
        <div className="wrapper">
          <Sidebar view={view} switchView={actions.switchView}/>
          <div className="main-content">
            {mainView}
          </div>
        </div>
      </div>
    );
  }
}

function mapState(state) {
  return {
    view: state.default.view,
    playing: state.default.playing,
    currentTrack: state.default.currentTrack,
    queueIndex: state.default.queueIndex,
    startTime: state.default.startTime,
    pausedDuration: state.default.pausedDuration,
    duration: state.default.duration,
    library: state.default.library,
    queue: state.default.queue
  };
}

function mapDispatch(dispatch) {
  return {
    actions: bindActionCreators(GrooveActions, dispatch)
  };
}

export default connect(mapState, mapDispatch)(GrooveApp);
