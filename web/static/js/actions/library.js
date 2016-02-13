import fetch from 'isomorphic-fetch';

export const REQUEST_LIBRARY = 'REQUEST_LIBRARY';
export const RECEIVE_LIBRARY  = 'RECEIVE_LIBRARY';

export const REQUEST_PLAYLISTS = 'REQUEST_PLAYLISTS';
export const RECEIVE_PLAYLISTS = 'RECEIVE_PLAYLISTS';

export const REQUEST_PLAYLIST = 'REQUEST_PLAYLIST';
export const RECEIVE_PLAYLIST = 'RECEIVE_PLAYLIST';

export const REQUEST_ARTIST_DETAILS = 'REQUEST_ARTIST_DETAILS';
export const RECEIVE_ARTIST_DETAILS = 'RECEIVE_ARTIST_DETAILS';

function requestLibrary(libraryType) {
  return { type: REQUEST_LIBRARY, libraryType };
}

function receiveLibrary(libraryType, library) {
  return { type: RECEIVE_LIBRARY, libraryType: libraryType, library };
}

export function fetchLibrary(libraryType) {
  return (dispatch, getState) => {
    if (getState().library[libraryType].length > 0) {
      return;
    }

    dispatch(requestLibrary(libraryType));

    return fetch('http://localhost:4000/api/' + libraryType)
      .then(response => response.json())
      .then(json => dispatch(receiveLibrary(libraryType, json.data)));
  };
}


function requestPlaylists() {
  return { type: REQUEST_PLAYLISTS };
}

function receivePlaylists(playlists) {
  return { type: RECEIVE_PLAYLISTS, playlists };
}

export function fetchPlaylists() {
  return (dispatch, getState) => {
    if (getState().library.playlists.length > 0) {
      return;
    }

    dispatch(requestPlaylists());

    return fetch('http://localhost:4000/api/playlists')
      .then(response => response.json())
      .then(json => dispatch(receivePlaylists(json.data)));
  };
}

function requestPlaylist(playlist_id) {
  return { type: REQUEST_PLAYLIST, playlist_id };
}

function receivePlaylist(playlist) {
  return { type: RECEIVE_PLAYLIST, playlist };
}

export function fetchPlaylist(playlist_id) {
  return (dispatch, getState) => {

    const playlist = getState().library.playlists.find((playlist) => {
      return playlist.id === playlist_id ? playlist : false;
    });
    if (playlist.tracks && playlist.tracks.length > 0) {
      return;
    }

    dispatch(requestPlaylist(playlist_id));

    return fetch('http://localhost:4000/api/playlists/' + playlist_id)
      .then(response => response.json())
      .then(json => dispatch(receivePlaylist(json.data)));
  };
}

function requestArtistDetails(artist_id) {
  return { type: REQUEST_ARTIST_DETAILS, artist_id };
}

function receiveArtistDetails(artist) {
  return { type: RECEIVE_ARTIST_DETAILS, artist };
}

export function fetchArtistDetails(artist_id) {
  return (dispatch, getState) => {
    const artist = getState().library.artists.find((artist) => {
      return artist.id === artist_id ? artist : false;
    });

    if (artist.tracks && artist.tracks.length > 0) {
      return;
    }

    dispatch(requestArtistDetails(artist_id));

    return fetch('http://localhost:4000/api/artists/' + artist_id)
      .then(response => response.json())
      .then(json => dispatch(receiveArtistDetails(json.data)));
  };
}

